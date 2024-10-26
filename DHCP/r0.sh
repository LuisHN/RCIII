#!/bin/sh

# Verifica os argumentos
if [ $# -ne 3 ]; then
  echo "Uso: $0 <T> <G> <MACC1>"
  exit 1
fi

T=$1
G=$2
MACC1=$3

requisitos() {
  apk add --no-cache iptables dhcp || { echo "Falha ao instalar pacotes"; exit 1; }
  rc-update add dhcpd
  rc-update add iptables
}

# alinea a & d
configurar_network_interfaces() {
  # Backup do arquivo de configuração de rede
  cp /etc/network/interfaces /etc/network/interfaces.bkp
  :> /etc/network/interfaces
  echo "
# Rede exterior 
auto eth0 
  eth0 inet dhcp

# Rede interligacao 172.20.TG.0/30
auto eth1
iface eth1 inet static
  address 172.20.${T}${G}.1
  netmask 255.255.255.252

# Rede 2 192.168.1TG.0/25
auto eth2
iface eth2 inet static
  address 192.168.1${T}${G}.126
  netmask 255.255.255.128
  Post-up route add -net 192.168.1${T}${G}.128 netmask 255.255.255.128 gw 172.20.${T}${G}.2 
      
      
      " >> /etc/network/interfaces

      service networking restart
}

#alinea b
ativar_encaminhamento_ip() {
  echo "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf 
  sysctl -p
}

#alinea c
ativar_static_nat() {
  # eth1 e eth2 são as interfaces ligadas às redes internas: 
  iptables -A FORWARD -i eth1 -j ACCEPT 
  iptables -A FORWARD -i eth2 -j ACCEPT 

  # eth0 é a interface externa ligada à Internet: 
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

  /etc/init.d/iptables save
}

#alinea e
configure_dhcp() {
  # Calcula valores para o turno e grupo
  RANGE_END=$((10 * G - T + 1))
  DEFAULT_LEASE_TIME_REDE_1=$((T * G + 20))
  MAX_LEASE_TIME_REDE_1=$((DEFAULT_LEASE_TIME_REDE_1 + 20))
  DEFAULT_LEASE_TIME_REDE_2=$((2 * T + G))
  MAX_LEASE_TIME_REDE_2=$((DEFAULT_LEASE_TIME_REDE_2 + 20))

  echo "
  subnet 192.168.1${T}${G}.0 netmask 255.255.255.128 { 
      range 192.168.1${T}${G}.2 192.168.1${T}${G}.${RANGE_END};
      option domain-name-servers 8.8.8.8; 
      option routers 192.168.1${T}${G}.126; 
      default-lease-time ${DEFAULT_LEASE_TIME_REDE_1}; 
      max-lease-time ${MAX_LEASE_TIME_REDE_1}; 
   }

   host hipotetico { 
      hardware ethernet EC:63:${T}${G}:AC:C8:9E; 
      fixed-address 192.168.1${T}${G}.${T}${G};
   }

   shared-network Rede1 { 
      subnet 192.168.1${T}${G}.128 netmask 255.255.255.128 { 
          range 192.168.1${T}${G}.130 192.168.1${T}${G}.200; 
          option domain-name-servers 8.8.8.8; 
          option routers 192.168.1${T}${G}.129; 
          default-lease-time ${DEFAULT_LEASE_TIME_REDE_1}; 
          max-lease-time ${MAX_LEASE_TIME_REDE_1}; 
      } 

      subnet 172.20.77.0 netmask 255.255.255.252 {
          # Rede diretamente ligada ao servidor
      } 

      host C1 {  
          hardware ethernet ${MACC1}; 
          fixed-address 192.168.1${T}${G}.21${G};  
      }  
   }
  " >> /etc/dhcp/dhcpd.conf

  rc-service dhcpd start
}

requisitos || { echo "Falha ao instalar requisitos"; exit 1; }
configurar_network_interfaces || { echo "Falha ao configurar interfaces de rede"; exit 1; }
ativar_encaminhamento_ip || { echo "Falha ao ativar encaminhamento IP"; exit 1; }
ativar_static_nat || { echo "Falha ao ativar NAT estático"; exit 1; }
configure_dhcp || { echo "Falha ao configurar DHCP"; exit 1; }
