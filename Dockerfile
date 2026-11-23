# =====================================================
# IMAGEN BASE
# =====================================================
# Utiliza una imagen oficial de PHP 8.5 con Apache
# preinstalado.
FROM php:8.5-apache

# =====================================================
# VARIABLES DE ENTORNO
# =====================================================
# Evita preguntas interactivas durante la instalación
# de paquetes con apt.
ARG DEBIAN_FRONTEND=noninteractive

# =====================================================
# INSTALACIÓN DE PAQUETES DEL SISTEMA
# =====================================================
# Instala:
# - sudo: ejecución de comandos privilegiados
# - cron: tareas programadas
# - proftpd-basic: servidor FTP
# - openssl: cifrado y certificados
# - python3: dependencias varias
# - certbot: obtención de certificados SSL
# - libzip-dev: soporte ZIP para PHP
# - nano: editor de texto
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    cron \
    proftpd-basic \
    openssl \
    apache2 \
    python3 \
    certbot \
    python3-certbot-apache \
    python3-acme \
    python3-josepy \
    python3-cryptography \
    libzip-dev \
    nano \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean

# =====================================================
# INSTALACIÓN DE LIBRERÍAS PARA GD
# =====================================================
# Se utilizan para:
# - Generación de imágenes
# - Manejo de JPG y PNG
# - Generación de códigos QR
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install gd \
  && docker-php-ext-install exif \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean

# =====================================================
# CONFIGURACIÓN GENERAL DE APACHE
# =====================================================
# Evita advertencias relacionadas con ServerName.
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# =====================================================
# CONFIGURACIÓN PERSONALIZADA DE PHP
# =====================================================
COPY php.ini /usr/local/etc/php/

# =====================================================
# CONFIGURACIÓN DEL SERVIDOR FTP
# =====================================================
COPY proftpd.conf /etc/proftpd/proftpd.conf
COPY ftpusers /etc/proftpd/ftpusers

# Archivo utilizado por el servidor SFTP
COPY users.conf /etc/sftp/users.conf

# =====================================================
# PERMISOS DE SEGURIDAD PARA FTP
# =====================================================

# El propietario debe ser root
RUN chown root:root /etc/proftpd/proftpd.conf
RUN chown root:root /etc/proftpd/ftpusers

# Lectura para todos, escritura únicamente root
RUN chmod 0644 /etc/proftpd/proftpd.conf

# Archivo sensible de usuarios FTP
RUN chmod 0600 /etc/proftpd/ftpusers

# =====================================================
# EXTENSIONES PHP
# =====================================================

# Soporte para archivos comprimidos ZIP
RUN docker-php-ext-install zip

# Soporte para MySQL mediante mysqli
RUN docker-php-ext-install mysqli

# Soporte para PDO
RUN docker-php-ext-install pdo

# Soporte para PDO MySQL
RUN docker-php-ext-install pdo_mysql

# =====================================================
# MÓDULOS DE APACHE
# =====================================================

# userdir:
# Permite acceder a:
# http://servidor/~usuario

RUN a2enmod userdir

# Rewrite para URLs amigables
RUN a2enmod rewrite

# Cabeceras HTTP personalizadas
RUN a2enmod headers

# Soporte SSL
RUN a2enmod ssl

# =====================================================
# CONFIGURACIÓN DEL MÓDULO USERDIR
# =====================================================
COPY userdir.conf /etc/apache2/mods-enabled/userdir.conf

# =====================================================
# CREACIÓN DEL USUARIO DE TRABAJO
# =====================================================

# Crear usuario Debian
# Crear directorio web
# Crear carpeta de logs
# Asignar propietario
RUN useradd -m debian && \
    mkdir -p /home/debian/public_html && \
    mkdir -p /var/log/apache2/debian && \
    chown -R debian:debian /home/debian/public_html && \
    chmod 711 /home/debian && \
    chmod 755 /home/debian/public_html

# =====================================================
# CONFIGURACIÓN DEL VIRTUALHOST
# =====================================================

# Copiar configuración del sitio web
COPY debian.fimaz.net.conf /etc/apache2/sites-available/debian.fimaz.net.conf

# Habilitar el sitio
RUN a2ensite debian.fimaz.net.conf

# Deshabilitar el sitio por defecto
RUN a2dissite 000-default.conf

# =====================================================
# PUERTOS EXPUESTOS
# =====================================================

# 21      FTP
# 80      HTTP
# 443     HTTPS
# 30000-30009 Puertos pasivos FTP
EXPOSE 21
EXPOSE 80
EXPOSE 443
EXPOSE 5000
EXPOSE 5001
EXPOSE 5002
EXPOSE 30000-30009

# =====================================================
# INICIO DE SERVICIOS
# =====================================================

# Inicia:
# 1. ProFTPD
# 2. Apache en primer plano
CMD ["bash", "-c", "proftpd -n & apache2-foreground"]