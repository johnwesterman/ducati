#!/bin/sh

# DEBUG=1 # uncomment this if you want to run in verbose mode.
PCE_ENV=/opt/illumio-pce/illumio-pce-env
PCE_CTL=/opt/illumio-pce/illumio-pce-ctl
PCE_DB=/opt/illumio-pce/illumio-pce-db-management
CERT_INSTALLED=/home/ilo-pce/cert-installed
PCE_ENVIRONMENT=/home/ilo-pce/pce-environment-installed

wait_indefinitely()
{
    while true; do 
        echo "Waiting for further input indefinitely to keep Docker image live. This message will repeat every hour. It is `date`."
        sleep 3600
    done
}

function pause()
{
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

# Require users to either accept EULA manually or place include in environment variable
function eula_agreement()
{
    echo "User must agree to the following EULA to continue with using the software."
    read  -p "Please enter 'yes ' to accept the EULA? " -t 30 user_input
    if ! [[ $user_input =~ ^[yY][eE][sS] ]]; then
        echo -e "\nEULA NOT ACCEPTED...Stopping installation\n"
        echo -e "-* You will need to remove this container before trying to run again.\n    docker rm pce"
        exit 1
    else
        echo "EULA Agreement Accepted....."
    fi
}

# Called only when PCE fully configured and PCE has been stopped
function run_pce()
{   
    # If upgrading make sure to migrate the DB before continuing
    echo "Starting the Illumio Policy Engine in Runlevel 1."
    $PCE_CTL start --runlevel 1 &&\
    $PCE_CTL status -sv -w 300
    echo "Run DB Migrate to upgrade DB data."
    $PCE_DB migrate
    echo "Start the PCE in Runleve 5."
    $PCE_CTL set-runlevel 5 &&\
    $PCE_CTL status -sv -w 300
}

# Called only when PCE fully configured and PCE has been stopped
function build_runtime()
{
    echo "Build runtime_env.yml file"
}

# Called only when PCE fully configured and PCE has been stopped
function decrypt_software()
{
    RPM_DIR=/home/ilo-pce

    echo "Unencrypting Illumio software:"
    if [[ -f $RPM_DIR/illumio-software.gpg ]]; then
        echo "Illuimo software found ... continuing ..."
    else
        echo "Illumio software was not found. Please fix this."
        sleep 5
        exit 1
    fi

    cd $RPM_DIR

    echo "Decrypting PCE software..."

    if [[ -n $DEBUG ]]; then
        echo "Debug mode is on. Skipping decryption process."
        continue
    else
        # Using the key provide decrypt the software provided
        # This decryption method is for openssl 1.1.1+ on RHEL8+
        echo "Unencrypting Illumio software bundle ..."
        openssl enc -d -aes256 -pbkdf2 -iter 1000 -salt -in illumio-software.gpg -k ${KEY} | tar xz
    fi
    echo "Decrypting software complete ..."

    # Remove the decryption key that was passed into this program.
    KEY=""
}

# Bring up the PCE for the first time
function environment_setup ()
{
    # decrypt PCE and VEN files.
    if [[ -n $SE ]]; then
        # if SE variable is present SE mode is on
        echo "SE mode is on. Skipping decryption process."
    else
        if [[ -z $KEY ]]; then
            echo -e "No encryption key provided. Presuming unencryption software provided."
            # echo -e "\n -* Cannot continue....Required Decryption Key not provided.  Please use -e KEY=<decryption key>"
            # exit 1
        else 
            decrypt_software
        fi
    fi

    # untar the PCE files if they exist in xz format
    echo -e "Extracting PCE software."
    echo -e "Installing CORE."

    if [ `ls -1 /home/ilo-pce/illumio-pce-sw-*.tgz  2>/dev/null | wc -l` -gt 0 ]; then
        if [ `ls -1 /home/ilo-pce/illumio-pce-sw-*.tgz  2>/dev/null | wc -l` -gt 1 ]; then
            echo "Only the first software in the list will be installed."
        fi
        # if GA tar.gz file is provided use this over all others.
        echo "Found GA software. Installing..."
        for i in /home/ilo-pce/illumio-pce-sw-*.tgz
        do
            SHORTNAME=`echo $i | sed -e 's/.*illumio-pce-sw-//g; s/\.tar\.bz2//g'`
            echo "Installing $SHORTNAME GA software."
            tar -xzf $i -C /opt/illumio-pce
            continue
        done
        echo "Done installing GA software."
    else
        # otherwise install non-GA software
        echo "Installing non-GA software..."
        for i in /home/ilo-pce/*.xz; do
            tar -xf "$i" -C /opt/illumio-pce ;
        done

        # if Thor is provide put it in it's place.
        chmod 770 /opt/illumio-pce/illumio/
        echo -e "Installing THOR."
        for i in /home/ilo-pce/thor*.tgz; do
            tar -zxf "$i" -C /opt/illumio-pce/ ;
        done
        chmod 550 /opt/illumio-pce/illumio/
    fi

    DISCOVERED_IP=$(hostname -i)
    echo "IP Address discovered - "$DISCOVERED_IP

    echo "Updating runtime_env.yml from Environment variables."
    if [[ ! -z $HOSTNAME ]] || [[ ! -z $DISCOVERED_IP ]]; then
        sed -e "s/HOSTNAME/${HOSTNAME}/g" \
            -e "s/LOGIN_BANNER/'${LOGIN_BANNER:=You are the force}'/" \
            -e "s/PCE_EMAIL_ADDRESS/${PCE_EMAIL_ADDRESS:=noreply@illumio.com}/" \
            -e  "s/PCE_FRONTEND_HTTPS_PORT/${PCE_FRONTEND_HTTPS_PORT:=8443}/" \
            -e "s/PCE_FRONTEND_EVENT_SERVICE_PORT/${PCE_FRONTEND_EVENT_SERVICE_PORT:=8444}/" \
            -e "s/PCE_FRONTEND_MANAGEMENT_HTTPS_PORT/${PCE_FRONTEND_MANAGEMENT_HTTPS_PORT:=8443}/" \
            -e "s/DISCOVERED_IP/$DISCOVERED_IP/"  /tmp/runtime_env.yml.template > /etc/illumio-pce/runtime_env.yml
    else 
        echo "-* Cannot continue....Required PCE environmental variables need to be set"
        exit 1
    fi

    # Add IP of Node running container if present.  Allows for external devices to reach the container.
    if [[ ! -z $EXTERNAL_IP ]]; then 
        echo -e "\n    - "$EXTERNAL_IP >> /etc/illumio-pce/runtime_env.yml
    fi

    echo "Creating self-signed certificate."
    # Create self-signed config file with HOSTNAME
    echo -e  "distinguished_name = req_dn\n[req_dn]\n[SAN]\nsubjectAltName=DNS:HOSTNAME\n\
    keyUsage=keyEncipherment,dataEncipherment,digitalSignature,keyCertSign\nextendedKeyUsage=serverAuth,clientAuth\n\
    subjectKeyIdentifier=hash\nbasicConstraints=CA:TRUE" | sed -e "s/HOSTNAME/${HOSTNAME}/" > /tmp/cert.conf

    openssl req \
        -subj "/CN=$HOSTNAME/O=Illumio Trial Authority" \
        -newkey rsa:2048 \
        -nodes \
        -keyout /var/lib/illumio-pce/cert/server.key \
        -x509 \
        -days ${DAYS:=120} \
        -out /var/lib/illumio-pce/cert/server.crt \
        -extensions SAN \
        -config /tmp/cert.conf \
        -sha256

    # set file permissions
    # echo "Setting file permissions..."
    # chmod -R 700 /var/lib/illumio-pce
    # chmod -R 700 /var/log/illumio-pce
    # chmod 400 /var/lib/illumio-pce/cert/server.key
    # chmod 440 /var/lib/illumio-pce/cert/server.crt

    if [[ -n $DEBUG ]]; then
        # Check the cert if in debug mode.
        echo "Checking environment ..."
        /opt/illumio-pce/illumio-pce-env check
        echo "Checking certificate ..."
        /opt/illumio-pce/illumio-pce-env setup --test 5 --list
        echo "End of checks."
    fi

    echo -e "\nStarting run level 1."
    $PCE_CTL start --runlevel 1 && \
    $PCE_CTL status -sv -w 300

    echo "Setting up the database."
    $PCE_DB setup

    echo "Starting run level 5."
    $PCE_CTL set-runlevel 5 &&\
    $PCE_CTL status -sv -w 300

    echo "Setting up the initial org and user in the database."
    ILO_PASSWORD=$PCE_PASSWORD $PCE_DB create-domain --full-name "${PCE_FULLNAME:=Demo Account} " \
        --user-name "${PCE_ADMIN_ACCOUNT:=demo@illumio.com}" --org-name "${PCE_ORG_NAME:=Demo}"

    echo "All PCE setup is completed."

    echo "Installing VEN compatibility bundles if they exist."
    if [ -e /home/ilo-pce/illumio-release-compatibility-*.bz2 ]; then
        echo "Found at least 1 compatibility matrix. Installing..."
        for i in /home/ilo-pce/illumio-release-compatibility-*.bz2
        do
            $PCE_CTL compatibility-matrix-install  $i --no-prompt
        done
        echo "Done installing compatibility matrix."
    else
        echo "No compatibility bundle existed for automated installation. Continuing..."
    fi

    echo "Installing VEN repos if they exist."
    if [ `ls -1 /home/ilo-pce/illumio-ven-bundle-*.bz2  2>/dev/null | wc -l` -gt 0 ]; then
        echo "Found at least 1 VEN repo. Installing..."
        for i in /home/ilo-pce/illumio-ven-bundle-*.bz2
        do
            # The following directory iteration order last bundle is the default,
            #   which might not be what you want. After installation the default
            #   ven repo can be established.
            SHORTNAME=`echo $i | sed -e 's/.*illumio-ven-bundle-//g; s/\.tar\.bz2//g'`
            echo "Installing $SHORTNAME VEN repo."
            $PCE_CTL ven-software-install --orgs 1 --default  $i --no-prompt
        done
        echo "Done installing VEN repos."
    else
        echo "No VEN repos existed for automated installation. Continuing..."
    fi

    if ! [[ -n $DEBUG ]]; then
        rm -f /home/ilo-pce/illumio-ven-bundle-*.bz2
    fi

    echo "Installation of PCE environment has completed."
    touch $PCE_ENVIRONMENT
}

#*****
#*****  Start
#*****

if [[ -n $DEBUG ]]; then
    continue
else
    echo -e "\n"
    cp /tmp/LICENSE /home/ilo-pce/ 
    cat /home/ilo-pce/LICENSE
fi

HOSTNAME=$(hostname -f)

#Check to see if PCE software installed
echo -e "\nIlluimo PCE software installed ... continuing ..."
if [ $ILLUMIO_ACCEPT_EULA ] || [ -e $PCE_ENVIRONMENT ]; then
    echo "EULA Agreement Accepted....." 
else 
    eula_agreement    
fi

echo "Starting Illumio PCE"
if [ ! -e $PCE_ENVIRONMENT ]; then
    echo "Initiate PCE environment for the first time."
    environment_setup
    #Print out access to the UI with admin account
    # THE HOSTNAME ASSIGNMENT LOOKS WRONG JWW June 10 2021
    echo -e "\nTo access the PCE you must be able to resolve the following FQDN - \
        \n      https://${HOSTNAME:=pce.test.local}:${PCE_FRONTEND_MANAGEMENT_HTTPS_PORT:=8443} \
        \n      user=${PCE_ADMIN_ACCOUNT:=demo@illumio.com} \
        \n      The password was provided as input at the start of this process. \
        \n"
else
    echo "Re-starting Illumio PCE."
    run_pce
    echo "PCE is starting ..."
fi

wait_indefinitely

#*****
#*****  End
#*****