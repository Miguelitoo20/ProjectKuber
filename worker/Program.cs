using System;
using System.Collections.Generic;
using StackExchange.Redis;
using Npgsql;
using System.Threading.Tasks;

class Worker
{
    static void Main(string[] args)
    {
        var redis = ConnectionMultiplexer.Connect("redis");
        var db = redis.GetDatabase();
        var connString = "Host=db;Username=postgres;Password=postgres;Database=postgres";

        using var conn = new NpgsqlConnection(connString);
        conn.Open();

        // Lista de canciones
        var tracks = new List<string> { "Track 1", "Track 2", "Track 3", "Track 4", "Track 5" };

        while (true)
        {
            // Procesar canciones en paralelo usando Task
            Parallel.ForEach(tracks, track =>
            {
                var votes = db.StringGet(track); // Obtener los votos de Redis
                if (!string.IsNullOrEmpty(votes))
                {
                    // Primero, intenta encontrar si ya hay un registro para la canción
                    var existingVotesCmd = new NpgsqlCommand("SELECT votes FROM votes WHERE track = @t", conn);
                    existingVotesCmd.Parameters.AddWithValue("t", track);
                    var existingVotes = existingVotesCmd.ExecuteScalar();

                    if (existingVotes != null)
                    {
                        // Si ya existe, actualiza el conteo de votos
                        int newVoteCount = (int)existingVotes + (int)votes;
                        using var updateCmd = new NpgsqlCommand("UPDATE votes SET votes = @v WHERE track = @t", conn);
                        updateCmd.Parameters.AddWithValue("v", newVoteCount);
                        updateCmd.Parameters.AddWithValue("t", track);
                        updateCmd.ExecuteNonQuery();
                    }
                    else
                    {
                        // Si no existe, inserta un nuevo registro
                        using var insertCmd = new NpgsqlCommand("INSERT INTO votes (track, votes) VALUES (@t, @v)", conn);
                        insertCmd.Parameters.AddWithValue("t", track);
                        insertCmd.Parameters.AddWithValue("v", (int)votes);
                        insertCmd.ExecuteNonQuery();
                    }

                    // Eliminar el voto de Redis después de procesarlo
                    db.KeyDelete(track);
                }
            });

            Console.WriteLine("Votes processed and stored in PostgreSQL.");
            System.Threading.Thread.Sleep(5000); // Procesar cada 5 segundos
        }
    }
}