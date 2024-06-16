#!/bin/bash

##################################################
#             Var / Const Definition             #
##################################################

okinput=true

NC=$(echo -en '\001\033[0m\002')
RED=$(echo -en '\001\033[00;31m\002')
GREEN=$(echo -en '\001\033[00;32m\002')
YELLOW=$(echo -en '\001\033[00;33m\002')
BLUE=$(echo -en '\001\033[00;34m\002')
MAGENTA=$(echo -en '\001\033[00;35m\002')
PURPLE=$(echo -en '\001\033[00;35m\002')
CYAN=$(echo -en '\001\033[00;36m\002')
WHITE=$(echo -en '\001\033[01;37m\002')

LIGHTGRAY=$(echo -en '\001\033[00;37m\002')
LRED=$(echo -en '\001\033[01;31m\002')
LGREEN=$(echo -en '\001\033[01;32m\002')
LYELLOW=$(echo -en '\001\033[01;33m\002')
LBLUE=$(echo -en '\001\033[01;34m\002')
LMAGENTA=$(echo -en '\001\033[01;35m\002')
LPURPLE=$(echo -en '\001\033[01;35m\002')
LCYAN=$(echo -en '\001\033[01;36m\002')


##################################################
#                   Functions                    #
##################################################

print_header () {
   clear
   echo ""
   echo -e "${YELLOW}     Welcome to the Modoboa Mail Server installer!${NC}"
   echo -e "${GREEN}"
   echo "     I need to ask you a few questions before starting the setup."
   echo ""
}

print_conf () {
   clear
   echo ""
   echo -e "${YELLOW}     Modoboa Mail Server installer${NC}"
   echo -e "${GREEN}"
   echo "     Your input is:"
   echo ""
}

get_fqdn_pw () {
   rpasswd=""
   FQDN=""

   print_header

   until [ ${#rpasswd} -gt 11 ]; do
       echo -en "${GREEN}     Enter new root password [min. length is 12 char]: ${YELLOW} "
       read -e -i "${rpasswd}" rpasswd
       if [ ${#rpasswd} -lt 12 ]; then
           print_header
	   echo -e "${LRED}     Password has too few characters"
       fi
    done

    print_header
    echo -e "${GREEN}     Enter new root password [min. length is 12 char]:  ${YELLOW}${rpasswd}"

    until [[ "$FQDN" =~ ^.*\..*$ ]]; do
    #   print_header
    #   echo -e "${GREEN}     Enter new root password [min. length is 12 char]:  ${YELLOW}${rpasswd}"
        echo -en "${GREEN}     Enter a full qualified domain name:               ${YELLOW} "
        read -e -i "${FQDN}" FQDN
        if [[ "$FQDN" =~ ^.*\..*$ ]]; then
            print_conf
            echo -e "${GREEN}     New root password:           ${YELLOW}${rpasswd}"
            echo -e "${GREEN}     Full qualified domain name:  ${YELLOW}${FQDN}"
        else
            print_header
            echo -e "${GREEN}     Enter new root password [min. length is 12 char]:  ${YELLOW}${rpasswd}"
            echo ""
            echo -e "${LRED}     The FQDN is not correct"   
        fi
     done

     echo -e "${NC}"
     read -r -p "     Ready to start installation [Y/n] ? " start_inst
     if [[ "$start_inst" = "" ]]; then
         start_inst="Y"
     fi
     if [[ "$start_inst" != [yY] ]]; then
         clear
         exit
     fi   
     hostnamectl set-hostname $FQDN  # set hostname
     echo "root:${rpasswd}" | chpasswd    # set root password -
}


ssh_hard () {

    echo "deb http://deb.debian.org/debian/ bookworm-backports main" | tee -a /etc/apt/sources.list   

    apt update
    apt upgrade -y

	###################################
	#### SSH Hardening
	#### https://sshaudit.com
	###################################

	#### Re-generate the RSA and ED25519 keys
	rm /etc/ssh/ssh_host_*
	ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
	ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

	#### Remove small Diffie-Hellman moduli
	awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe
	mv /etc/ssh/moduli.safe /etc/ssh/moduli

	#### Restrict supported key exchange, cipher, and MAC algorithms
	echo -e "# Restrict key exchange, cipher, and MAC algorithms, as per sshaudit.com\n# hardening guide.\n\nKexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,gss-curve25519-sha256-,diffie-hellman-group16-sha512,gss-group16-sha512-,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256\n\nCiphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr\n\nMACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com\n\nHostKeyAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256\n\nRequiredRSASize 3072\n\nCASignatureAlgorithms sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256\n\nGSSAPIKexAlgorithms gss-curve25519-sha256-,gss-group16-sha512-\n\nHostbasedAcceptedAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-256\n\nPubkeyAcceptedAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-256\n\n" > /etc/ssh/sshd_config.d/ssh-audit_hardening.conf
 
    #### Change SSH port and some config parameters
	#sed -i "s|\#Port 22|Port 49153|g" /etc/ssh/sshd_config
	sed -i "s|\#MaxAuthTries 6|MaxAuthTries 4|g" /etc/ssh/sshd_config
	sed -i "s|X11Forwarding yes|X11Forwarding no|g" /etc/ssh/sshd_config
	sed -i "s|session    required     pam_env.so user_readenv=1 envfile=/etc/default/locale|session    required     pam_env.so envfile=/etc/default/locale|g" /etc/pam.d/sshd

    # Restart SSH: Port changed to 49153
    systemctl restart sshd
    sleep 5
}

server_env () {

    cd /root
    wget https://raw.githubusercontent.com/fdmgit/modoboa/main/bashrc.ini
    cp bashrc.ini /root/.bashrc
    cp bashrc.ini /etc/skel/.bashrc
    rm /root/bashrc.ini
    . .bashrc

    ###################################
    #### Setup root key file
    ###################################

	if [ -d /root/.ssh ]; then 
		echo ".ssh exists"
	else
		mkdir /root/.ssh
	fi

	if [ -f /root/.ssh/authorized_keys ]; then
		echo "file authorized_keys exists"
	else
		cd /root/.ssh
		wget https://raw.githubusercontent.com/fdmgit/virtualmin/main/authorized_keys
	fi
}


inst_pre_tasks () {
    apt install git plocate htop -y   
}

inst_modoboa () {
	cd /root
	git clone https://github.com/modoboa/modoboa-installer
	cd modoboa-installer
	./run.py --stop-after-configfile-check $FQDN
	sed -i "s|type = self-signed|type = letsencrypt|g" /root/modoboa-installer/installer.cfg
	sed -i "s|email = admin@example.com|email = admin@${FQDN}|g" /root/modoboa-installer/installer.cfg
	sed -i "s|engine = postgres|engine = mysql|g" /root/modoboa-installer/installer.cfg	
	sed -i "s|timezone = Europe/Paris|timezone = Europe/Zurich|g" /root/modoboa-installer/installer.cfg
}
 
 

closing_msg () {
# Closing message after completion of installation
    
    # Retrieve the IP address
    ip_address=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${YELLOW}ATTENTION\\n"
    echo -e "${GREEN}The port for SSH has changed. To login use the following comand:\\n"
    echo -e "        ssh root@${ip_address} -p 49153${NC}\\n"
    echo ""
}


#####################################################################################
#                             MODOBOA MAIL SERVER                                   #
#####################################################################################

#### Pre-installation

get_fqdn_pw
ssh_hard
server_env
inst_pre_tasks
inst_modoboa
closing_msg

reboot
