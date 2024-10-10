const express = require('express');
const { Pool } = require('pg');
const app = express();

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

// Ruta principal para resultados
app.get('/results', async (req, res) => {
    try {
        // Consultar la cantidad de votos por película
        const result = await pool.query('SELECT movie_voted, COUNT(*) as votes FROM votes GROUP BY movie_voted');
        res.json(result.rows);
    } catch (err) {
        res.status(500).send(err);
    }
});

// Ruta para recomendaciones
app.get('/recommendations/:userId', async (req, res) => {
    const userId = req.params.userId;
    
    // Aquí deberías conectar a Redis para obtener las recomendaciones
    // Deberías tener algo como esto:
    res.json({ message: `No recommendations yet for user ${userId}` });
});

app.listen(5002, () => {
    console.log('Result app listening on port 5002');
});
