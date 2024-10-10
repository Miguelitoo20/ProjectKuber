import redis
import dask.dataframe as dd  # Cambia pandas por dask.dataframe
from flask import Flask, jsonify, request

app = Flask(__name__)

# Conexión a Redis
r = redis.Redis(host='redis', port=6379, decode_responses=True)

# Cargar los datos de MovieLens usando Dask
movies = dd.read_csv('/mnt/data/movies.dat', sep="::", engine='python', names=["MovieID", "Title", "Genres"])
ratings = dd.read_csv('/mnt/data/ratings.dat', sep="::", engine='python', names=["UserID", "MovieID", "Rating", "Timestamp"])
users = dd.read_csv('/mnt/data/users.dat', sep="::", engine='python', names=["UserID", "Gender", "Age", "Occupation", "Zip-code"])

# Función para calcular recomendaciones basadas en género usando Dask
def recommend_by_genre(movie_voted, user_id):
    # Obtener el género de la película votada (Usando Dask para filtrar)
    genre = movies[movies['Title'] == movie_voted]['Genres'].compute().values[0]  # .compute() para realizar el cálculo
    
    # Encontrar películas del mismo género
    similar_movies = movies[movies['Genres'].str.contains(genre)]
    
    # Obtener las películas mejor valoradas por otros usuarios
    best_movies = ratings[ratings['MovieID'].isin(similar_movies['MovieID'])].groupby('MovieID')['Rating'].mean().compute().sort_values(ascending=False)
    
    # Tomar la mejor película que el usuario no haya votado aún
    recommended_movie_id = best_movies.index[0] if len(best_movies) > 0 else None

    if recommended_movie_id is not None:
        recommended_movie_title = movies[movies['MovieID'] == recommended_movie_id]['Title'].compute().values[0]
        return recommended_movie_title
    return None

# Servicio de recomendación
@app.route('/recommend', methods=['POST'])
def recommend():
    user_id = request.json['user_id']
    movie_voted = request.json['movie_voted']

    # Generar una recomendación
    recommendation = recommend_by_genre(movie_voted, user_id)

    # Guardar la recomendación en Redis
    if recommendation:
        r.set(f"user:{user_id}:recommendations", str([recommendation]))

    return jsonify({"recommendation": recommendation})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
