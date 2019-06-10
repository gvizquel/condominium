# Vamos a usar una imagen con python 3.7 de alpine (imagen mucho mas pequeña)
FROM python:3.7-alpine AS python

# Prevents Python from writing pyc files to disc
ENV PYTHONDONTWRITEBYTECODE 1

# Prevents Python from buffering stdout and stderr
ENV PYTHONUNBUFFERED 1

# Creamos un usuario y su directorio de trabajo
RUN addgroup -S webgroup && adduser -S webuser -G webgroup -h /home/webapp

# Establecemos el directorio de trabajo
WORKDIR /home/webapp

# Copiamos las dependencias del proyecto a la nueva imagen de Docker en el directorio /tmp
COPY requirements.txt /tmp/

# install psycopg2 and pillow
RUN apk update \
    && apk add --no-cache postgresql-dev \
    && apk add --no-cache jpeg-dev zlib-dev \
    # && apk add supervisor \
    && apk add --no-cache --virtual .build-deps build-base linux-headers

# Actualizamos pip
RUN pip install --upgrade pip

# Instalamos las dependencias en la nueva imagen de Docker
RUN python -m pip install --no-cache-dir -r /tmp/requirements.txt --no-index

RUN apk del .build-deps && rm -rf /var/cache/apk/*

# Copiamos solo los archivos innecesarios del proyecto al directorio de trabajo
COPY ./apps /home/webapp/apps/
COPY ./bin/gunicorn_start.sh /home/webapp/bin/gunicorn_start.sh
COPY ./condominium /home/webapp/condominium/
COPY ./media /home/webapp/media/
COPY ./run /home/webapp/run/
COPY ./entrypoint.sh ./manage.py /home/webapp/

# creamos el archivo de logs
RUN touch /var/log/gunicorn.log

# Hacemos propietario del directorio al usuario que creamos y como grupo a root
RUN chown -R webuser:root /home/webapp/ /var/log/gunicorn.log

# Ejecutamos el entrypoint.sh = Esperar que levante la base de datos, migrar
# los datos, recojer los estaticos y levantar el demonio de supervisor
ENTRYPOINT ["/home/webapp/entrypoint.sh"]

# Establecemos el usuario  de trabajo para dejar de trabajar con root
USER webuser

# -------------------------------------------------------------------------- #
# Vamos a usar una imagen con nginx 1.15 de alpine (imagen mucho mas pequeña)
FROM nginx:1.15-alpine AS nginx

RUN addgroup -S webgroup && adduser -S webuser -G webgroup -h /home/webapp

# Sobre escribir la configuración por defecto de nginx
# COPY virtual-host.conf /etc/nginx/conf.d/default.conf

# COPY --from=python /home/webapp/static /home/webapp/static
# Esta opción quiza es la menos efectiva pero es la que hasta ahora encuentro
# para poder hacer una simulación del ambiente de producción mas efectiva.
COPY ./static /home/webapp/static/

# Establecemos el usuario  de trabajo para dejar de trabajar con root
USER webuser
