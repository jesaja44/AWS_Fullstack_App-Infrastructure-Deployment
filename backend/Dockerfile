# Verwende ein Python-Image als Basis
FROM python:3.9-slim

# Setze das Arbeitsverzeichnis im Container
WORKDIR /app

# Kopiere die Anforderungen und installiere sie
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopiere den Rest des Projekts ins Containerverzeichnis
COPY . .

# Definiere den Befehl zum Starten der Anwendung
CMD ["python", "run.py"]

