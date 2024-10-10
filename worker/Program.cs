using System;
using StackExchange.Redis;
using Npgsql;

class Worker
{
    static void Main(string[] args)
    {
        var redis = ConnectionMultiplexer.Connect("redis");
        var db = redis.GetDatabase();
        var connString = "Host=db;Username=postgres;Password=postgres;Database=postgres";

        using var conn = new NpgsqlConnection(connString);
        conn.Open();

        while (true)
        {
            foreach (var movie in new[] { "Movie 1", "Movie 2", "Movie 3", "Movie 4", "Movie 5" })
            {
                var votes = db.StringGet(movie); // Obtener los votos de Redis
                if (!string.IsNullOrEmpty(votes))
                {
                    // Primero, intenta encontrar si ya hay un registro para la película
                    var existingVotesCmd = new NpgsqlCommand("SELECT votes FROM votes WHERE movie = @m", conn);
                    existingVotesCmd.Parameters.AddWithValue("m", movie);
                    var existingVotes = existingVotesCmd.ExecuteScalar();

                    if (existingVotes != null)
                    {
                        // Si ya existe, actualiza el conteo de votos
                        int newVoteCount = (int)existingVotes + (int)votes;
                        using var updateCmd = new NpgsqlCommand("UPDATE votes SET votes = @v WHERE movie = @m", conn);
                        updateCmd.Parameters.AddWithValue("v", newVoteCount);
                        updateCmd.Parameters.AddWithValue("m", movie);
                        updateCmd.ExecuteNonQuery();
                    }
                    else
                    {
                        // Si no existe, inserta un nuevo registro
                        using var insertCmd = new NpgsqlCommand("INSERT INTO votes (movie, votes) VALUES (@m, @v)", conn);
                        insertCmd.Parameters.AddWithValue("m", movie);
                        insertCmd.Parameters.AddWithValue("v", (int)votes);
                        insertCmd.ExecuteNonQuery();
                    }

                    // Eliminar el voto de Redis después de procesarlo
                    db.KeyDelete(movie);
                }
            }

            Console.WriteLine("Votes processed and stored in PostgreSQL.");
            System.Threading.Thread.Sleep(5000); // Procesar cada 5 segundos
        }
    }
}
