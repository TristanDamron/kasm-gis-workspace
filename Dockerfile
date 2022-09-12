FROM ghcr.io/j-simmons-phd/kasm-core-ubuntu-focal:develop
USER root

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
WORKDIR $HOME

######### Customize Container Here ###########

# copy over install_files/ for use in playbooks
ADD install_files $HOME/install_files
RUN apt update && apt install -y sudo

# Install QGIS 
RUN apt install -y qgis

# Install QGIS Server + Apache
RUN apt install -y qgis-server apache2 libapache2-mod-fcgid

# Install PostgreSQL, PostGIS, and PG Admin
RUN apt install -y postgresql && apt install -y postgis 
RUN curl https://www.pgadmin.org/static/packages_pgadmin_org.pub | apt-key add && sh -c 'echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list && apt update'
RUN apt install -y pgadmin4-desktop

# Install Python packages with pip 
RUN apt install -y python3-pip && pip install pint

# Copy QGIS Server conf file to container
COPY devResources/geocml.demo.conf /etc/apache2/sites-available/geocml.demo.conf

# Create QGIS Server directories
# TODO: Do this in Ansible, not in the Dockerfile
RUN mkdir -p /var/log/qgis
RUN chown www-data:www-data /var/log/qgis
RUN mkdir -p /home/qgis/qgisserverdb
RUN chown www-data:www-data /home/qgis && cd /home/qgis && chown -R www-data:www-data *
RUN a2enmod fcgid
RUN a2ensite geocml.demo
RUN service apache2 restart
# TODO: do we really need to restart here?
# Replace 127.0.0.1 with the IP of your server.
RUN sh -c 'echo "127.17.02.2 geocml.demo" >> /etc/hosts'``.
# Server will be available at http://geocml.demo/cgi-bin/qgis_mapserv.fcgi?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities
RUN chown www-data:www-data /var/log/apache2/ && cd /var/log/apache2/ && chown -R www-data:www-data *

# install Ansible per 
# https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-ubuntu
RUN add-apt-repository --yes --update ppa:ansible/ansible && apt install -y ansible && rm -rf /var/lib/apt/lists/*

# run Ansible commands
COPY ./requirements.yaml ./playbook.yaml ./
RUN ansible-galaxy install -r requirements.yaml && ansible-playbook -i,localhost playbook.yaml --tags "all" && rm -f ./*.yaml
# Custom Desktop Background - replace bg_custom.png on disk with your own background image

# Uninstall Ansible stuff
RUN rm -rf ~/.ansible
RUN apt remove -y ansible

COPY ./bg_custom.png /usr/share/extra/backgrounds/bg_default.png

# Create .profile and set XFCE terminal to use it
RUN cp /etc/skel/.profile $HOME/.profile && mkdir $HOME/.config/xfce4/terminal/
COPY ./terminalrc /home/kasm-default-profile/.config/xfce4/terminal/terminalrc

COPY devResources/su /etc/pam.d/su

# clean up install_files/
RUN rm -rf $HOME/install_files/

######### End Customizations ###########

RUN chown 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME

ENV HOME /home/kasm-user
WORKDIR $HOME
USER default
