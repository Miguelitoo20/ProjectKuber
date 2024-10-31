const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');
const app = express();

// Configurar el cliente de Redis
const redisClient = redis.createClient({ host: 'redis', port: 6379 });
redisClient.on('error', (err) => console.error('Redis Client Error', err));

// Conexión a PostgreSQL
const pool = new Pool({
    user: 'postgres',
    host: 'db',
    database: 'postgres',
    password: 'postgres',
    port: 5432
});

// Middleware para servir archivos estáticos
app.use(express.static('public'));

// Ruta principal para resultados de votación
app.get('/results', async (req, res) => {
    try {
        // Consulta para obtener la cantidad de votos por canción
        const result = await pool.query('SELECT song_voted, COUNT(*) as votes FROM votes GROUP BY song_voted');
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching results:', err);
        res.status(500).send('Error fetching results');
    }
});

// Ruta para obtener los últimos 3 votos y sus recomendaciones
app.get('/latest-votes', async (req, res) => {
    try {
        // Consulta para obtener los últimos 3 votos
        const latestVotesResult = await pool.query('SELECT user_id, track_voted, song_voted FROM votes ORDER BY id DESC LIMIT 3');
        const latestVotes = latestVotesResult.rows;

        // Mapa para almacenar recomendaciones por usuario
        const recommendations = {};

        // Obtener las recomendaciones del servicio Redis
        for (const vote of latestVotes) {
            const userId = vote.user_id;

            // Espera a que la llamada a Redis se complete
            await new Promise((resolve, reject) => {
                redisClient.get(`recommendations:${userId}`, (err, recs) => {
                    if (err) {
                        reject(err);
                    } else {
                        recommendations[userId] = recs ? recs.split(',') : [];
                        resolve();
                    }
                });
            });
        }

        // Combinar votos con sus recomendaciones
        const combinedResults = latestVotes.map(vote => ({
            user_id: vote.user_id,
            track_voted: vote.track_voted,
            song_voted: vote.song_voted,
            recommendations: recommendations[vote.user_id] || []
        }));

        res.json(combinedResults);
    } catch (err) {
        console.error('Error fetching latest votes:', err);
        res.status(500).send('Error fetching latest votes');
    }
});

// Ruta para recomendaciones de canciones
app.get('/recommendations/:userId', async (req, res) => {
    const userId = req.params.userId;

    try {
        // Obtener las recomendaciones del servicio Redis basado en el userId
        redisClient.get(`recommendations:${userId}`, (err, recommendations) => {
            if (err) {
                console.error('Error fetching recommendations:', err);
                return res.status(500).send('Error fetching recommendations');
            }
            if (recommendations) {
                res.json({ recommendations: recommendations.split(',') });
            } else {
                res.json({ message: `No recommendations yet for user ${userId}` });
            }
        });
    } catch (err) {
        console.error('Error in recommendations route:', err);
        res.status(500).send('Error processing request');
    }
});

// Iniciar el servidor
app.listen(5002, () => {
    console.log('Result app listening on port 5002');
});