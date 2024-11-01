#!/bin/bash
#
# Automação de DHCP
#
# Andrei Henrique Santos
# CVS $Header$

shopt -s -o nounset

interface_default="/etc/default/isc-dhcp-server"
dir_dhcp="/etc/dhcp"
conf="dhcpd.conf"
loop=true

# Título
echo "Inicando Servidor DHCP..."

# Validando permissão de super usuário
if [[ "EUID" -ne 0 ]]; then
	echo "Necessário estar em modo super usuário!"
	sleep 3
	exit 1
fi

# Atualizando pacotes
apt-get update -y && apt-get upgrade -y
sleep 4

# Verificando se o serviço dhcp já existe
if [ ! -e "$interface_default" ]; then
	echo "O servidor DHCP não está instalado"
	echo "Instalando servidor..."
	sleep 3
	apt-get install isc-dhcp-server -y
	sleep 4
else
	echo "O servidor DHCP já está instalado!!!"
	echo "Deseja continuar a configuração mesmo assim? (S / N)"
	read verificar
	if [[ "$verificar" == "N" || "$verificar" == "n" ]]; then
		exit 1
	fi
	sleep 2
fi

# Limpando configuração default
cp "$dir_dhcp/$conf" "$dir_dhcp/$conf.bkp"
rm "$dir_dhcp/$conf"

# Configurando
echo "---------------------------------------------------"
echo "Hora de configurar o Servidor!!"
echo "É necessário que algumas informações sejam passadas"
echo "---------------------------------------------------"
echo "* - Obrigatório informar algo"
echo "Se preferir não informar coloque - 0"
echo "---------------------------------------------------"
echo "Deseja adicionar ip estático a máquina virtual? (S / N)"
read verificar
if [[ "$verificar" == "S" || "$verificar" == "s" ]]; then
	echo "O IP que este servidor DHCP terá:*"
	read ip_fixo
	echo "A sua máscara de rede:*"
	read mask_fixo
	echo "O seu gateway:"
	read gateway

	echo "Interface em que o DHCP estará instalado:* (coloque entre aspas)"
	read interface

	# Configurando em que interface o DHCP vai entregar IPs
	{
	sed -i '17 s/""//' $interface_default
	sed -i "s|INTERFACESv4=|INTERFACESv4=$interface|g" $interface_default
	} >>"$interface_default"

	# Configurando IP estático
	interface=${interface:1:6}
	{
	if [[ "$gateway" == "0" ]]; then
		sed -i "s|iface $interface inet dhcp|iface $interface inet static \naddress $ip_fixo \nnetmask $mask_fixo|" "/etc/network/interfaces"
	else
		sed -i "s|iface $interface inet dhcp|iface $interface inet static \naddress $ip_fixo \nnetmask $mask_fixo \ngateway $gateway|" "/etc/network/interfaces"
	fi
	} >>"/etc/network/interfaces"
else
	echo "Interface em que o DHCP estará instalado:* (coloque entre aspas)"
	read interface

	# Configurando em que interface o DHCP vai entregar IPs
	{
	sed -i '17 s/""//' $interface_default
	sed -i "s|INTERFACESv4=|INTERFACESv4=$interface|g" $interface_default
	} >>"$interface_default"
fi

echo "Domínio:* (coloque entre aspas)"
read dominio
echo "DNS: (IP)"
read dns
echo "Lease time:* (Segundos)"
read lease_time
echo "Rede que deseja compartilhar:*"
read subnet
echo "Máscara da rede a compartilhar:*"
read netmask
echo "Deseja utilizar esse Servidor DHCP como autoritativo? (S / N)"
read verificar

# Configuração do dhcp.conf
{

echo -e "option domain-name $dominio;\n"

if [[ ! "$dns" == "0" ]]; then
	echo -e "option domain-name-servers $dns;\n"
fi

echo -e "default-lease-time $lease_time;\n"

if [[ "$verificar" == "S" || "$verificar" == "s" ]]; then
	echo -e "authoritative;\n"
fi

echo "subnet $subnet netmask $netmask {"
} >>"$dir_dhcp/$conf"

while [[ loop==true ]]; do
	echo "Range de IPs:* (Separe IPs com espaço)"
	read range

	# Configuração do dhcp.conf
	{
	echo "     range $range;"
	} >>"$dir_dhcp/$conf"

	echo "Deseja adicionar mais um range? (S / N)"
	read verificar
	if [[ "$verificar" == "N" || "$verificar" == "n" ]]; then
		break
	fi

done

echo "Máscara do range:*"
read subnet_mask
echo "Gateway: (Ip1, Ip2...)"
read routers

# Configuração do dhcp.conf
{

echo "     option subnet-mask $subnet_mask;"

if [[ ! "$routers" == "0" ]]; then
	echo "     option routers $routers;"
fi

echo -e "}\n"
} >>"$dir_dhcp/$conf"

echo "Deseja reservar um ip a um mac address? (S / N)"
read verificar
if [[ "$verificar" == "S" || "$verificar" == "s" ]]; then
	while [[ loop==true ]]; do
		echo "Ip que deseja reservar:*"
		read reserva_ip
		echo "Mac address associado a este ip:* (utilize : para separar o mac address)"
		read mac_address
		echo "O nome desta reserva:*"
		read reserva

		# Configuração do dhcp.conf
		{

		echo "host $reserva {"
		echo "     hardware ethernet $mac_address;"
		echo "     fixed-address $reserva_ip;"
		echo "     option domain-name $dominio;"

		if [[ ! "$dns" == "0" ]]; then
			echo "     option domain-name-servers $dns;"
		fi

		if [[ ! "$routers" == "0" ]]; then
			echo "     option routers $routers;"
		fi

		echo -e "}\n"
		} >>"$dir_dhcp/$conf"

		echo "Deseja adicionar mais uma reserva de ip? (S / N)"
		read verificar
		if [[ "$verificar" == "N" || "$verificar" == "n" ]]; then
			break
		fi
	done
fi

# Configurando o resolv.conf
if [[ ! "$dns" == "0" ]]; then
	rm "/etc/resolv.conf"
	touch "/etc/resolv.conf"
	{
	echo "nameserver $dns"
	} >>"/etc/resolv.conf"
fi

echo "----------------------------------------------------------------------"
echo "Configuração realizada com sucesso!!!"
echo "Desligaremos a máquina para que possa colocar em rede interna..."
echo "----------------------------------------------------------------------"
sleep 3
init 0
