#!/bin/sh

# Verifica os argumentos
if [ $# -ne 2 ]; then
  echo "Uso: $0 <T> <G>"
  exit 1
fi

T=$1
G=$2

# Instala os pacotes necessários
requisitos() {
    apk add --no-cache bind
}

# Configura o named.conf
Configurar_named_conf() {
    echo "
options { 
    directory \"/var/cache/bind\"; 
    listen-on { any; }; 
    listen-on-v6 { none; }; 
    allow-query { any; }; 
    allow-transfer { none; }; 
    allow-recursion { any; }; 
    recursion yes; 
    check-names master ignore; 
    forwarders { 8.8.8.8; }; 
    forward only; 
    dnssec-validation yes; 
}; 
 
logging { 
    channel default_log { 
        file \"/var/log/bind/default\" versions 3 size 100m;  
        severity info; 
        print-time yes; 
        print-category yes; 
        print-severity yes; 
    }; 
    category default { default_log; }; 
}; 
 
zone \"rc3${T}${G}.test\" IN { 
    type master; 
    file \"/etc/bind/rc3${T}${G}.test\"; 
}; 
 
zone \"77.20.172.in-addr.arpa\" IN { 
    type master; 
    file \"/etc/bind/rc3${T}${G}.${T}${G}.20.172\"; 
}; 
 
zone \"177.168.192.in-addr.arpa\" IN { 
    type master; 
    file \"/etc/bind/rc3${T}${G}.1${T}${G}.168.192\"; 
};
" > /etc/bind/named.conf

    mkdir -p /var/cache/bind /var/log/bind
    chmod 777 /var/cache/bind
    touch /var/log/bind/default
    chmod 777 /var/log/bind/default
}

# Configura a zona de pesquisa direta
Configurar_Forward_Lookup_Zone() {
    SERIAL=$(date +"%Y%m%d")"00"
    REFRESH=$((T * 3600 + G * 10 * 60))
    RETRY=$((T * G * 60))
    EXPIRE=$(((20 - T + G) * 7 * 24 * 3600))
    MINIMUM=$((T * 3600))

    echo "
\$TTL 2d
\$ORIGIN rc3${T}${G}.test.
@	IN SOA ns1.rc3${T}${G}.test. hostmaster.rc3${T}${G}.test. (
    $SERIAL	; serial
    $REFRESH	; refresh
    $RETRY	; retry
    $EXPIRE	; expire
    $MINIMUM	; minimum caching
)
	IN	NS	ns1.rc3${T}${G}.test.
	IN	MX	10	mail.rc3${T}${G}.test.

ns1		IN	A	172.20.${T}${G}.1
mail	IN	A	192.168.1${T}${G}.125
app		IN	A	192.168.1${T}${G}.21${G}
webserver	IN	A	192.168.1${T}${G}.21${G}
r1		IN	A	172.20.${T}${G}.2
" > /etc/bind/rc3${T}${G}.test

    echo "
\$TTL 1d
@	IN	SOA	ns1.rc3${T}${G}.test. hostmaster.rc3${T}${G}.test. (
    $SERIAL	; serial
    $REFRESH	; refresh
    $RETRY	; retry
    $EXPIRE	; expire
    $MINIMUM	; minimum caching
)
@	IN	NS	ns1.rc3${T}${G}.test.;
2	IN	PTR	r1.rc3${T}${G}.test.;
" > /etc/bind/rc3${T}${G}.${T}${G}.20.172

    echo "
\$TTL 1d
@	IN	SOA	ns1.rc3${T}${G}.test. hostmaster.rc3${T}${G}.test. (
    $SERIAL	; serial
    $REFRESH	; refresh
    $RETRY	; retry
    $EXPIRE	; expire
    $MINIMUM	; minimum caching
)
@	IN	NS	ns1.rc3${T}${G}.test.;
125	IN	PTR	mail.rc3${T}${G}.test.;
210	IN	PTR	app.rc3${T}${G}.test.;
210	IN	PTR	webserver.rc3${T}${G}.test.;
" > /etc/bind/rc3${T}${G}.1${T}${G}.168.192
}

# Configura o servidor DHCP para usar o DNS atualizado
Configurar_DHCP_Server() {
    local dhcpd_conf="/etc/dhcp/dhcpd.conf"

    if [ -f "$dhcpd_conf" ]; then
        sed -i "s/option domain-name-servers .*/option domain-name-servers 172.20.${T}${G}.1;/" "$dhcpd_conf"
        rc-service dhcpd restart
    else
        echo "Erro: Arquivo $dhcpd_conf não encontrado."
        return 1
    fi
}

# 2.3 Criar servico APP
Configurar_App() {
        apk add --no-cache php7 php7-fpm php7-mysqli mariadb mariadb-client nginx

    # Instala o WordPress
    wget https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
    tar -xzvf /tmp/wordpress.tar.gz -C /var/www
    mv /var/www/wordpress /var/www/app.rc3${T}${G}.test

    service mariadb setup
    rc-service mariadb start
    mysql -e "CREATE DATABASE wordpress;"
    mysql -e "CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'password';"
    mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    cp /var/www/app.rc3${T}${G}.test/wp-config-sample.php /var/www/app.rc3${T}${G}.test/wp-config.php
    sed -i "s/database_name_here/wordpress/" /var/www/app.rc3${T}${G}.test/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/app.rc3${T}${G}.test/wp-config.php
    sed -i "s/password_here/password/" /var/www/app.rc3${T}${G}.test/wp-config.php

    echo "
server {
    listen 80;
    server_name app.rc3${T}${G}.test;
    root /var/www/app.rc3${T}${G}.test;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
" > /etc/nginx/conf.d/app.rc3${T}${G}.test.conf

    rc-service php-fpm7 restart
    rc-service nginx restart
}

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

# Executa as funções com verificação de sucesso
requisitos || { echo "Falha ao instalar pacotes"; exit 1; }
Configurar_named_conf || { echo "Falha ao configurar named.conf"; exit 1; }
Configurar_Forward_Lookup_Zone || { echo "Falha ao configurar Forward Lookup Zone"; exit 1; }
Configurar_DHCP_Server || { echo "Falha ao configurar DHCP"; exit 1; }

rc-update add named
rc-service named start