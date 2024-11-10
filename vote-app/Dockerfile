FROM python:3.8-slim

WORKDIR /app

# Crear el directorio de datos
RUN mkdir -p /mnt/data

# Copiar requirements.txt primero para aprovechar el caché
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el archivo de datos al directorio correcto
COPY ./data/spotify_songs.csv /mnt/data/

# Copiar el resto de la aplicación
COPY . .

EXPOSE 80

CMD ["python", "app.py"]