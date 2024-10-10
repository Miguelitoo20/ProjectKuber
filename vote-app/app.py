from flask import Flask, render_template, request, redirect
import redis
import pandas as pd
import psycopg2

app = Flask(__name__)

# Conexión a Redis y PostgreSQL
r = redis.Redis(host='redis', port=6379, decode_responses=True)
conn = psycopg2.connect(host="db", database="postgres", user="postgres", password="postgres")
cur = conn.cursor()

# Cargar las películas de MovieLens
movies = pd.read_csv('/mnt/data/movies.dat', sep="::", engine='python', names=["MovieID", "Title", "Genres"], encoding='latin1')

# Función para obtener una película por género
def get_movies_by_genre():
    genres = movies['Genres'].str.split('|').explode().unique()  # Obtener todos los géneros únicos
    selected_movies = []
    for genre in genres:  # Seleccionar una película por cada género
        movie = movies[movies['Genres'].str.contains(genre)].sample(1)  # Seleccionar una película por género
        selected_movies.append(movie.iloc[0])
    return selected_movies

# Ruta principal para mostrar las opciones de votación y recomendaciones
@app.route('/')
def index():
    movie_options = get_movies_by_genre()  # Obtener películas de diferentes géneros
    recommendations = request.args.get('recommendations', [])  # Obtener las recomendaciones si existen
    return render_template('index.html', movies=movie_options, recommendations=recommendations)

# Ruta para manejar la votación y generar recomendaciones
@app.route('/vote', methods=['POST'])
def vote():
    user_id = request.form['user_id']
    movie_voted = request.form['movie']
    
    # Almacenar la votación en Redis
    r.incr(movie_voted)
    
    # Generar recomendaciones
    genre = movies[movies['Title'] == movie_voted]['Genres'].values[0]
    similar_movies = movies[movies['Genres'].str.contains(genre)]['Title'].sample(3).tolist()

    # Almacenar en PostgreSQL
    cur.execute("INSERT INTO votes (user_id, movie_voted, recommendations) VALUES (%s, %s, %s)", 
                (user_id, movie_voted, ','.join(similar_movies)))
    conn.commit()

    # Redirigir a la página principal con las recomendaciones
    return redirect(f'/?recommendations={",".join(similar_movies)}')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
