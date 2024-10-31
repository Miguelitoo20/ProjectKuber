from flask import Flask, render_template, request, redirect
import redis
import pandas as pd
import psycopg2
import time

app = Flask(__name__)

# Conexión a Redis y PostgreSQL
r = redis.Redis(host='redis', port=6379, decode_responses=True)
conn = psycopg2.connect(host="db", database="postgres", user="postgres", password="postgres")
cur = conn.cursor()

# Crear la tabla votes si no existe
def create_votes_table():
    cur.execute("""
        CREATE TABLE IF NOT EXISTS votes (
            id SERIAL PRIMARY KEY,
            user_id INT,
            track_voted VARCHAR(100),
            recommendations TEXT
        );
    """)
    conn.commit()

# Llamar a la función para crear la tabla
create_votes_table()

# Cargar las canciones de Spotify
spotify_songs = pd.read_csv('/mnt/data/spotify_songs.csv')

# Función para obtener una canción por género de playlist
def get_tracks_by_genre():
    genres = spotify_songs['playlist_genre'].unique()  # Obtener todos los géneros de playlist únicos
    selected_tracks = []
    for genre in genres:  # Seleccionar una canción por cada género
        track = spotify_songs[spotify_songs['playlist_genre'] == genre].sample(1)  # Seleccionar una canción aleatoria por género
        selected_tracks.append(track.iloc[0])
    return selected_tracks

# Ruta principal para mostrar las opciones de votación y recomendaciones
@app.route('/')
def index():
    track_options = get_tracks_by_genre()  # Obtener canciones de diferentes géneros
    recommendations = request.args.get('recommendations', '')  # Obtener las recomendaciones si existen
    return render_template('index.html', tracks=track_options, recommendations=recommendations)

# Ruta para manejar la votación y generar recomendaciones
@app.route('/vote', methods=['POST'])
def vote():
    user_id = request.form['user_id']
    track_voted = request.form['track']

    if not track_voted:  # Verificar si track_voted está vacío
        return redirect('/')

    # Almacenar la votación en Redis
    r.incr(track_voted)
    
    # Generar recomendaciones basadas en el género de la canción votada
    genre = spotify_songs[spotify_songs['track_name'] == track_voted]['playlist_genre'].values
    if genre.size == 0:  # Verificar si el género existe
        return redirect('/')

    genre = genre[0]
    similar_tracks = spotify_songs[spotify_songs['playlist_genre'] == genre]['track_name'].sample(3).tolist()

    # Almacenar en PostgreSQL
    try:
        cur.execute("INSERT INTO votes (user_id, track_voted, recommendations) VALUES (%s, %s, %s)", 
                    (user_id, track_voted, ','.join(similar_tracks)))
        conn.commit()
    except Exception as e:
        conn.rollback()  # Revertir en caso de error
        print(f"Error al insertar el voto: {e}")
        return redirect('/')  # Redirigir sin recomendaciones en caso de error
    
    time.sleep(3)

    # Redirigir a la página principal con las recomendaciones
    return redirect(f'/?recommendations={",".join(similar_tracks)}')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)