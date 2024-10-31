import redis
import dask.dataframe as dd  # Usamos Dask para cargar y manejar grandes datasets
from flask import Flask, jsonify, request

app = Flask(__name__)

# Conexión a Redis
r = redis.Redis(host='redis', port=6379, decode_responses=True)

# Cargar los datos de canciones de Spotify usando Dask
spotify_songs = dd.read_csv('/mnt/data/spotify_songs.csv')

# Función para calcular recomendaciones basadas en el género de la playlist
def recommend_by_genre(track_voted, user_id):
    # Obtener el género de la canción votada (Usando Dask para filtrar)
    genre = spotify_songs[spotify_songs['track_name'] == track_voted]['playlist_genre'].compute().values[0]  
    
    # Encontrar canciones del mismo género de playlist
    similar_songs = spotify_songs[spotify_songs['playlist_genre'] == genre]
    
    # Filtrar las canciones más populares de este género
    top_songs = similar_songs[['track_name', 'track_popularity']].compute()
    top_songs = top_songs.sort_values(by='track_popularity', ascending=False)
    
    # Tomar la canción más popular que el usuario no haya votado aún
    recommended_song = top_songs['track_name'].values[0] if len(top_songs) > 0 else None

    return recommended_song

# Servicio de recomendación
@app.route('/recommend', methods=['POST'])
def recommend():
    user_id = request.json['user_id']
    track_voted = request.json['track_voted']

    # Generar una recomendación
    recommendation = recommend_by_genre(track_voted, user_id)

    # Guardar la recomendación en Redis
    if recommendation:
        r.set(f"user:{user_id}:recommendations", str([recommendation]))

    return jsonify({"recommendation": recommendation})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)