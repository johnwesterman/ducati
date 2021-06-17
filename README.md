
# Illumio Adaptive Security Platform Policy Compute Engine (PCE) in a docker container

   version c8 v1 Thursday June 17, 2021 12:42

## About this container

The container contains a install script that will build a single node Policy Compute Engine (SNC) in a container with the supplied credentials and data. During the run process an encryption key, agreement to the the EULA, a password to set up the demo user account, and the hostname FQDN will be required. This password will be used to access the demo user account. Unless changed in the DOCKERFILE the demo user will have an ID of "demo@illumio.com".

Below in the "starting the container" section you can find a full list fo variables that can be set at runtime to override the default.  The runtime variables can be set via "-e" on the command line or via a file using the "--env-file" option(e.g. --env-list env.list).

## What is needed to run this Docker container

* Docker runtime environment.
* An encrypted PCE software bundle deployed to the ./ directory (project root directory).
* An encrypted VEN bundle (optional) deployed to the ./ directory.
* Full documentation for the Illumio ASP platform can be publically obtained at here: <https://docs.illumio.com/>.
* For shortened notes on what it take to install a PCE in any environment you can reference <https://github.com/johnwesterman/illumio_core>
* Encryption keys to unencrypt the PCE and VEN files provided. If you need encryption keys please contact Illumio.

## Background before the build process is started

By default, the PCE will be installed with a host name of pce.test.local. Make sure this host name can be resolved on your local machine by modifying the "hosts" file locally. On a Mac and other Linux machines the file is located at /etc/hosts and should have contents similar to this:

    127.0.0.1 localhost pce.test.local

If a different hostname is required you can modify the name by changing --hostname value to the new name of the PCE during initial runtime configuration.  This name should be resolvable by any machine accessing the PCE.  This means the user accessing the UI as well as the VENs using the PCE s its controlling system.

## EULA ACCEPTANCE REQUIRED 

The ability to use the following software require you accept the EULA. Found at the bottom of the page.   To do that you will need to either set ILLUMIO_ACCEPT_EULA=true in the env.list file.  Optionally, you can provide the ILLUMIO_ACCEPT_EULA==true using the 'docker run -e ILLUMIO_ACCEPT_EULA=true' method. Failure to do so with not allow the software to install.

## How to build the Docker image

Using the supplied Dockerfile, build the container as follows:

    docker build --tag illumio-docker-pce .

The tag name can be anything you want but it will be referenced when you run the container.

## ENTRYPOINT

The ENTRYPOINT will be a script: /usr/bin/illumio.sh. This script will start the container, validate variables pass in via command or present in env.list to build the PCE, decrypt, install and configure the software as well as keep the container running until it is manually stopped.

## Starting the container

To start the container fully automated run this command:

    docker run -it -p 8443:8443 -p 8444:8444 --env-file env.list -e ILLUMIO_ACCEPT_EULA=true -e KEY=[encryption key]-e PCE_PASSWORD=[password] --hostname pce.test.local --name pce illumio-docker-pce
    
Explanation of the command line arguments:

* -it interactive terminal.  To run the install in a detached container you can replace -it with -d.  Just make sure at least ILLUMIO_ACCEPT_EULA and PCE_PASSWORD are passed as environment variables.  
* -p 8443:8443 - expose frontend service on localhost - If changing make sure to also alter PCE_FRONTEND_HTTPS_PORT 
* -p 8444:8444 - expose event service on localhost - If changing make sure to also alter PCE_FRONTEND_EVENT_SERVICE_PORT
* --env-file file containing environmental variables used in startup/install scripts.  Default file is env.list
* -e an environment passed to startup scrips.  To fully automate installation ILLUMIO_ACCEPT_EULA=true and PCE_PASSWORD=<password> must be set otherwise install will prompt user.

    Variables that can be overridden by setting the environment variable using '-e' option.  Also, can add the variables in a file like env.list above:
    * KEY - Encryption key proivided by illumio personnelused to allow extraction of software for use by trusted users.
    * PCE_ADMIN_ACCOUNT - Initial admin account to access the PCE.  (default - 'demo@illumio.com')
    * PCE_PASSWORD - Password to access the PCE admin account.
    * PCE_EMAIL_ADDRESS - Emails sent using this email address.  (default - 'noreply@illumio.com').
    * PCE_FULLNAME - Name that appears in the system for the admin account.     (default - 'Demo Account').
    * LOGIN_BANNER - Banner on the login page.    (default - 'You are the force').
    * PCE_FRONTEND_HTTPS_PORT - PCE port used for agent (VEN -Virtual Enforcment Node) connectivity and UI if PCE_FRONTEND_MANAGEMENT_HTTPS_PORT not set. If set just VEN connectivity. (default - 8443)
    * PCE_FRONTEND_EVENT_SERVICE_PORT - PCE port used sa long lived connection to VEN to push policy updates.   (default - 8444)
    * PCE_FRONTEND_MANAGEMENT_HTTPS_PORT - PCE port used to access the UI if set otherwise UI uses PCE_FRONTEND_HTTPS_PORT. (default - 8443)
    * EXTERNAL_IP   -   If testing ENFORCEMENT this variable MUST be set to the IP address of the node running the PCE container or the IP address used when resolving PCE_FQDN     

* --hostname - sets the docker hostname AND the FQDN of the PCE console.  Change if you want to change the FQDN that will be used by the software
* --name - sets the docker name
* illumio-docker-pce - name of the docker image which comes from the docker build step.

If you do not provide a password for PCE_PASSWORD or a value of true for ILLUMIO_ACCEPT_EULA at runtime you will be asked to accept the EULA and/or enter a password during the installation of the software. If you do supply PCE_PASSWORD and ILLUMIO_ACCEPT_EULA as environment variables the system should run installation steps and finish in 3-5 minutes without user intervention.

## Using the Policy Engine

The startup process completes in around 5 minutes to come to a fully running state. Wait these few minutes for the container to start. Once the process is complete and the PCE is fully up and operational you can use a web browser to connect to PCE GUI if using the default PCE_FQDN at this URL:

    https://pce.test.local:8443/

* If you need you want to change the name of the URL FQDN change the --hostname in the initial docker run command.  Make sure the hostname is resolvable.   If not using an interactive console check the logs for the following: "Installation of PCE environment is completed."  This will indicate that the system has finished startup.

## Build script

The entire container build, run, install and setup can be run from a single script provide in this build environment. You will find the commands described above inside the script "build.sh". Running this script will run through each of the steps to build this docker image into a running policy compute engine ready to be used to pair VENs and build policy in a test environment.

* The build.sh script will automatically include the docker build and run EULA acceptance requirements.

This script takes one arguments:

* the initial password for the demo user account

Usage: build.sh USER_PASSWORD KEY

## Starting and stopping the PCE

After the initial Docker run you may want to stop the PCE using:

    docker stop pce

To restart the PCE:

    docker start [-ai] pce

Stopping and starting the PCE in this way will use the original container created above with all the persistent data needed to run the PCE. Once the container is started it will try to start itself.  This can take a few minutes to come up.  If you find that the system is not operational you can run the folliwng "docker exec" command 

* "/opt/illumio-pce/illumio-pce-ctl start" - Start all the processes of the PCE
* "/opt/illumio-pce/illumio-pce-ctl stop" - stop all the processes of the PCE
* "/opt/illumio-pce/illumio-pce-ctl restart" - stop all the processes of the PCE
* "/opt/illumio-pce/illumio-pce-ctl status"  - Displays the operational status of PCE
* "/opt/illumio-pce/illumio-pce-ctl status -sv"  - Displays the operational status of all the compnents of the PCE

Sample of the exact docker command: 

* docker exec -it pce /opt/illumio-pce/illumio-pce-ctl start

## How can I access my PCE from the command line

Execute the following command:

    docker exec -it pce bash

## Copying files to the PCE container

    docker cp <filename> pce:/some/path

## About the volumes used

This image will automatically create two docker volumes.

* /var/lib/illumio
* /var/log/illumio

## Software installed

Directories for installing software:

* ./ - this will be copied to /home/ilo-pce, any encrypted files in there will be installed. It is also the place to put VEN bundles where they will be installed using ven-software-install.  All encrypted VEN bundles in the directory will be installed.

## A note on operational scale

This container is intended for a test environment and solely to test feature functionality. It is not intended to scale beyond a test of 5-10 workloads. When creating the environment you will need to insure you have allocated enough resources to run the software.  Allocating 4-6GB of RAM, 4+ cores and 100G of hard disk space in the shared environment is recommended.

## A note on the Docker build environment

This software was developed inside of Docker using standard Docker images to build the latest LTS version of Policy Compute Engine. Doing these steps creates various images in the Docker environment. If those images are no longer needed you can delete them. If you want to build things from scratch delete all related images and rebuild this image and run a fresh container.

## Warning messages

Because this is a container environment, the "system" services will not be running. Time syncronization will be left to the container host. As such, you will receive these warning which can be ignored:

Warning: Found 1 warning in PCE runtime environment
 1: ntp check failed; 'chronyd' or 'ntpd' is not running.

Warning: Unable to change ownership of /etc/illumio-pce/runtime_env.yml to root:ilo-pce
Warning: Directory /var/lib/illumio-pce/cert owned by ilo-pce
Warning: Unable to secure ownership of /var/lib/illumio-pce/cert/server.crt
Warning: Some files may be inaccessible to the runtime user.


## License

BY SIGNING ABOVE OR USING THE SOFTWARE PRODUCTS PROVIDED TO YOU BY ILLUMIO, INC. (“ILLUMIO”) UNDER AN ORDER FORM (“SOFTWARE”), YOU (THE INDIVIDUAL OR LEGAL ENTITY, HEREIN REFERED TO AS “YOU” OR “YOUR” OR “USER”) AGREE TO BE BOUND BY THIS END USER LICENSE AGREEMENT (“AGREEMENT”). IF YOU DO NOT AGREE TO THE TERMS OF THIS AGREEMENT, YOU MUST NOT DOWNLOAD, INSTALL OR USE THE SOFTWARE AND YOU MUST DELETE THE SOFTWARE IMMEDIATELY. NOTWITHSTANDING THE FOREGOING, THIS AGREEMENT SHALL NOT APPLY AND SHALL NOT BIND ANY PARTY, IF YOU AND ILLUMIO HAVE ENTERED INTO A SEPARATE AGREEMENT FOR USE OF THE SOFTWARE AND SUCH AGREEMENT STATES THAT IT SHALL SUPERSEDE THIS AGREEMENT.

1. License. Subject to the terms and conditions of this Agreement, Illumio grants to you a limited, non-exclusive, non-transferable, non-sublicensable license to use the Software, in executable form only, for internal purposes and only on servers owned or controlled by you (the “License”). You may not, and may not permit or aid others to, translate, reverse engineer, decompile, disassemble, update, modify, reproduce, duplicate, copy, distribute or otherwise disseminate all or any part of the Software, or extract source code from the object code of the Software.
2. Proprietary Rights; Confidentiality. You acknowledge and agree that the Software is a proprietary product of Illumio, protected under copyright laws and international treaties. You further acknowledge and agree that all right, title and interest in and to the Software and any derivatives thereof are and shall remain with Illumio. All intellectual property rights (including, without limitation, copyrights, trade secrets, trademarks, etc.) evidenced by or embodied in and/or attached/connected/related to the Software, including any revisions, corrections, modifications, enhancements, updates and/or upgrades thereof (to the extent provided by Illumio) are and shall be owned solely by Illumio.
3. Term; Termination. The License is effective until terminated by you or Illumio. Your rights under license will terminate if you fail to remedy any non-compliance with the term(s) of the Agreement within thirty (30) days after written notice from Illumio. Upon termination, you shall cease all use of the Software and destroy all copies, full or partial, of the Software.
4. Open Source. Notwithstanding anything herein to the contrary, Open Source Software (as defined below) is licensed to you under the license terms for such Open Source Software. The Open Source Software license terms are consistent with the License granted in this Agreement, and may contain additional rights benefiting you. The Open Source Software license terms shall take precedence over this Agreement to the extent that this Agreement imposes greater restrictions on you than the applicable Open Source Software license terms. To the extent the license for any Open Source Software requires Illumio to make available to you the corresponding source code and/or modifications (the "Source Files"), you may obtain a copy of the applicable Source Files by sending a written request, with your name and address to: Illumio, Inc., 920 De Guigne Avenue, Sunnyvale, California, United States of America. All requests should clearly specify: Open Source Files Request, Attention: Legal Department. This offer to obtain a copy of the Source Files is valid for three years from the date you acquired this Software. As used herein, “Open Source Software” means software components embedded in the Software and provided under separate license terms, which can be found in the Open Source Software disclosure file (or similar file) provided within the Software.
5. Compliance. The Software may be subject to United States export control regulations. Without prior authorization from the United States government, you shall not use the Software for, and shall not permit the Software to be used for, any purposes prohibited by United States law, including, without limitation, for any prohibited development, design, manufacture or production of missiles or nuclear, chemical or biological weapons. Without limiting the foregoing, You represent and warrant that: (a) You are not, and are not acting on behalf of, any person who is a citizen, national, or resident of, or who is controlled by the government of, Cuba, Iran, North Korea, Sudan, or Syria, or any other country to which the United States has prohibited export transactions; (b) You are not located in a country that is subject to a U.S. Government embargo, or that has been designated by the U.S. Government as a “terrorist supporting” country; and (c) You are not, and are not acting on behalf of, any person or entity listed on the U.S. Treasury Department list of Specially Designated Nationals and Blocked Persons, or the U.S. Commerce Department Denied Persons List, Unverified List, or Entity List or any other U.S. Government list of prohibited or restricted parties unless authorized by license or regulation.
6. No Warranty. TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE SOFTWARE IS PROVIDED “AS IS” AND “AS AVAILABLE”, WITH ALL FAULTS AND WITHOUT WARRANTY OF ANY KIND, AND LICENSOR HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS WITH RESPECT TO THE SOFTWARE, EITHER EXPRESS, IMPLIED OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES AND/OR CONDITIONS OF MERCHANTABILITY, OF SATISFACTORY QUALITY, OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY, OF QUIET ENJOYMENT, AND NON-INFRINGEMENT OF THIRD PARTY RIGHTS. SHOULD THE SOFTWARE PROVE DEFECTIVE, ILLUMIO WILL PERFORM ALL NECESSARY SERVICING, REPAIR OR CORRECTION. SOME JURISDICTIONS DO NOT ALLOW THE EXCLUSION OF IMPLIED WARRANTIES OR LIMITATIONS ON APPLICABLE STATUTORY RIGHTS OF A CONSUMER, SO THE ABOVE EXCLUSION AND LIMITATIONS MAY NOT APPLY TO YOU.
7. Limitation of Liability. UNDER NO CIRCUMSTANCES WILL ILLUMIO BE LIABLE TO YOU FOR ANY INDIRECT, INCIDENTAL, CONSEQUENTIAL, SPECIAL OR EXEMPLARY DAMAGES, FOR LOSS OF PROFITS, USE, REVENUE, OR DATA OR FOR BUSINESS INTERRUPTION (REGARDLESS OF THE LEGAL THEORY FOR SEEKING SUCH DAMAGES OR OTHER LIABILITY) ARISING OUT OF OR IN CONNECTION WITH USE OF THE SOFTWARE, WHETHER OR NOT LICENSOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. IN ADDITION, THE LIABILITY OF ILLUMIO ARISING OUT OF OR RELATING TO THE SOFTWARE WILL NOT EXCEED THE AMOUNT PAID OR PAYABLE BY YOU (IF ANY) FOR SUCH SOFTWARE.
8. General. This Agreement shall be governed by and construed in accordance with the laws of the State of California, regardless of its conflict of laws rules. This Agreement constitutes the entire agreement between Illumio and You with respect to its subject matter and may not be modified except by a written instrument executed by You and an authorized representative of Illumio.

This Docker image was built in accordance to https://repo1.dsop.io/dsop/dccscr/tree/master/contributor-onboarding.