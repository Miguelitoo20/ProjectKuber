# Fase de construcción
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /app

# Copiar todos los archivos del proyecto al contenedor
COPY . .

# Restaurar dependencias y compilar el proyecto
RUN dotnet restore
RUN dotnet publish -c Release -o /out

# Fase de ejecución
FROM mcr.microsoft.com/dotnet/runtime:8.0

WORKDIR /app

# Copiar los archivos publicados desde la fase de construcción
COPY --from=build /out .

# Comando para ejecutar la aplicación
ENTRYPOINT ["dotnet", "worker.dll"]
