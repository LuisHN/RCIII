#!/bin/sh

# Verifica os argumentos
if [ $# -ne 2 ]; then
  echo "Uso: $0 <T> <G>"
  exit 1
fi

T=$1
G=$2

# 2.3 Criar servico Web
Configurar_Web() {
     apk add --no-cache nginx

    # Cria o diretório e uma página HTML com informações sobre o grupo
    mkdir -p /var/www/webserver.rc3${T}${G}.test
    echo "
<!DOCTYPE html>
<html lang=\"pt\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Informações do Grupo</title>
</head>
<body>
    <h1>Informações sobre os elementos do grupo</h1>
    <p>Nome do Grupo: Grupo RC3-${T}${G}</p>
    <ul>
        <li>Membro 1: Nome e detalhes</li>
        <li>Membro 2: Nome e detalhes</li>
        <li>Membro 3: Nome e detalhes</li>
        <!-- Adicione outros membros aqui -->
    </ul>
</body>
</html>
" > /var/www/webserver.rc3${T}${G}.test/index.html

    # Configura o NGINX para o servidor web
    echo "
server {
    listen 80;
    server_name webserver.rc3${T}${G}.test;
    root /var/www/webserver.rc3${T}${G}.test;

    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
" > /etc/nginx/conf.d/webserver.rc3${T}${G}.test.conf

    rc-service nginx restart
}

# 2.3 Criar servico APP
Configurar_App() {
     apk add --no-cache nginx

    # Cria o diretório e uma página HTML com informações sobre o grupo
    mkdir -p /var/www/app.rc3${T}${G}.test
    echo "
<!DOCTYPE html>
<html lang=\"pt\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Simulador APP</title>
</head>
<body>
    <h1>Isto é uma APP</h1>

    </ul>
</body>
</html>
" > /var/www/app.rc3${T}${G}.test/index.html

    # Configura o NGINX para o servidor web
    echo "
server {
    listen 80;
    server_name app.rc3${T}${G}.test;
    root /var/www/app.rc3${T}${G}.test;

    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
" > /etc/nginx/conf.d/app.rc3${T}${G}.test.conf

    rc-service nginx restart
}

Configurar_App || { echo "Falha a configurar app"; exit 1; }
Configurar_Web || { echo "Falha a configurar web"; exit 1; }
