import redis
import dask.dataframe as dd
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest

app = Flask(__name__)

# Conexión a Redis
r = redis.Redis(host='redis', port=6379, decode_responses=True)

# Cargar los datos de canciones de Spotify usando Dask
spotify_songs = dd.read_csv('/mnt/data/spotify_songs.csv')

# Métricas de Prometheus
REQUEST_COUNT = Counter('request_count', 'Número de peticiones', ['endpoint'])
REQUEST_LATENCY = Histogram('request_latency_seconds', 'Latencia de solicitudes en segundos', ['endpoint'])
RECOMMENDATION_COUNTER = Counter('recommendation_counter', 'Número de recomendaciones generadas', ['genre'])
REDIS_CONNECTION_GAUGE = Gauge('redis_connection_status', 'Estado de la conexión a Redis')

# Verificar el estado de la conexión a Redis
def check_redis_connection():
    try:
        r.ping()
        REDIS_CONNECTION_GAUGE.set(1)
    except redis.ConnectionError:
        REDIS_CONNECTION_GAUGE.set(0)

# Función para calcular recomendaciones basadas en el género de la playlist
def recommend_by_genre(track_voted, user_id):
    genre_row = spotify_songs[spotify_songs['track_name'] == track_voted]
    if genre_row.empty:
        return None

    genre = genre_row['playlist_genre'].compute().values[0]
    RECOMMENDATION_COUNTER.labels(genre=genre).inc()

    similar_songs = spotify_songs[spotify_songs['playlist_genre'] == genre]
    top_songs = similar_songs[['track_name', 'track_popularity']].compute()
    top_songs = top_songs.sort_values(by='track_popularity', ascending=False)

    for song in top_songs['track_name'].values:
        if song != track_voted:
            return song
    return None

# Servicio de recomendación
@app.route('/recommend', methods=['POST'])
def recommend():
    REQUEST_COUNT.labels(endpoint='/recommend').inc()
    check_redis_connection()

    with REQUEST_LATENCY.labels(endpoint='/recommend').time():
        user_id = request.json.get('user_id')
        track_voted = request.json.get('track_voted')

        if not user_id or not track_voted:
            return jsonify({"error": "Faltan parámetros obligatorios"}), 400

        recommendation = recommend_by_genre(track_voted, user_id)
        if recommendation:
            r.set(f"user:{user_id}:recommendations", str([recommendation]))

        return jsonify({"recommendation": recommendation})

# Ruta de métricas de Prometheus
@app.route('/metrics')
def metrics():
    return generate_latest(), 200

# Ruta de verificación de salud
@app.route('/health')
def health_check():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
