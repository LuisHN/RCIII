#!/bin/sh

# Verifica os argumentos
if [ $# -ne 2 ]; then
  echo "Uso: $0 <T> <G>"
  exit 1
fi

T=$1
G=$2



requisitos() {
    apk add --no-cache bind 
}

# alinea c
Configurar_named_conf() {
    echo "
options { 
directory "var/bind"; 
listen-on { any; }; 
listen-on-v6 { none; }; 
alow-query {any; }; 
allow-transfer { none; }; 
allow recursion { any; }; 
recursion yes; 
check-names master ignore; 
forwarders { 8.8.8.8; }; 
forward only 
dnssec-validation yes; 
}; 
 
logging { 
channel default_log { 
file "/var/log/bind/default" versions 3 size 100m;  
severity info; 
print-time yes; 
print-cetegory yes; 
print severity yes; 
}; 
category deafult {default_log; }; 
}; 
 
zone "rc3${T}${G}.test" IN { 
type master; 
file "etc/bind/rc3${T}${G}.test"; 
}; 
 
zone "77.20.172.in-addr.arpa" IN { 
type master; 
file "/etc/bind/rc3${T}${G}.${T}${G}.20.172"; 
}; 
 
zone "177.168.192.in-addr.arpa" IN { 
type master; 
file "/etc/bind/rc3${T}${G}.1${T}${G}.168.192"; 
};
    " >> /etc/bind/named.conf

    chmod 660 /var/log/bind/default
}

# alinea d
Configurar_Forward_Lookup_Zone() {
SERIAL=$(date +"%Y%m%d")"00"

# Calcula o período para sincronização com slaves (refresh)
REFRESH=$((T * 3600 + G * 10 * 60))

# Calcula o tempo entre tentativas de comunicação falhadas com slaves (retry)
RETRY=$((T * G * 60))

# Calcula o tempo para os slaves deixarem de ser autoritários (expire)
EXPIRE=$(((20 - T + G) * 7 * 24 * 3600))

# Calcula o tempo máximo para caching de erros de domínios não existentes (minimum)
MINIMUM=$((T * 3600))

    echo "
\$TTL 2d
\$ORIGIN rc3${T}${G}.test.
@	IN SOA ns1.rc3${T}${G}.test. hostmaster.rc3${T}${G}.test. (
    $SERIAL	; serial - parâmetros diferentes para cada grupo
    $REFRESH		; refresh
    $RETRY		; retry
    $EXPIRE		; expire
    $MINIMUM		; caching de outros domínios
)
	IN	NS	ns1.rc3${T}${G}.test.
	IN	MX	10	mail.rc3${T}${G}.test.

ns1			IN	A	172.20.${T}${G}.1
mail		IN	A	192.168.1${T}${G}.125
app			IN	A	192.168.1${T}${G}.21${G}
webserver	IN	A	192.168.1${T}${G}.21${G}
r1			IN	A	172.20.${T}${G}.2
" > /etc/bind/rc3${T}${G}.test

    echo "
\$TTL 1d
@	IN	SOA	ns1.rc3${T}${G}.test. hostmaster.rc3${T}${G}.test. (
    $SERIAL	; serial - valores diferentes para cada grupo
    3h		; refresh
    1h		; retry
    1w		; expire
    1d		; minimum
)

@	IN	NS	ns1.rc3${T}${G}.test.
2	IN	PTR	r1.rc3${T}${G}.test.
" > /etc/bind/rc3${T}${G}.${T}${G}.20.172

    echo "
\$TTL 1d
@	IN	SOA	ns1.rc3${T}${G}.test. hostmaster.rc3${T}${G}.test. (
    $SERIAL	; serial
    3h		; refresh
    1h		; retry
    1w		; expire
    1d		; minimum
)

@	IN	NS	ns1.rc3${T}${G}.test.
125	IN	PTR	mail.rc3${T}${G}.test.
210	IN	PTR	app.rc3${T}${G}.test.		; endereço definido para C1
210	IN	PTR	webserver.rc3${T}${G}.test.	; endereço definido para C1
" > /etc/bind/rc3${T}${G}.1${T}${G}.168.192
}

# Configurar o DHCP
Configurar_DHCP_Server() {
    sed -i 's/option domain-name-servers .*/option domain-name-servers 172.20.${T}${G}.1;/' /etc/dhcp/dhcpd.conf

    rc-service dhcpd restart
}

requisitos || { echo "Falha ao instalar pacotes"; exit 1; }
Configurar_named_conf || { echo "Falha ao configurar named.conf"; exit 1; }
Configurar_Forward_Lookup_Zone || { echo "Falha ao configurar Forward Lookup Zone"; exit 1; }
Configurar_DHCP_Server || { echo "Falha ao configurar DHCP"; exit 1; }