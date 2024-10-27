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
210	IN	PTR	app.rc3-${T}${G}.test.;
210	IN	PTR	webserver.rc3-${T}${G}.test.;
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


# Executa as funções com verificação de sucesso
requisitos || { echo "Falha ao instalar pacotes"; exit 1; }
Configurar_named_conf || { echo "Falha ao configurar named.conf"; exit 1; }
Configurar_Forward_Lookup_Zone || { echo "Falha ao configurar Forward Lookup Zone"; exit 1; }
Configurar_DHCP_Server || { echo "Falha ao configurar DHCP"; exit 1; }

rc-update add named
rc-service named start