Resultado esperado

Para concluir el proyecto de manera exitosa, se deberá entregar un repositorio privado en GitHub que contenga un conjunto de scripts SQL organizados y un archivo README.md explicativo. El objetivo es que el "trainer" pueda clonar el repositorio y ejecutar los archivos en secuencia para recrear la base de datos y validar todas las funcionalidades implementadas.



Requisitos de Entrega en GitHub
Creación del Repositorio: Cada equipo o individuo deberá crear un repositorio privado en GitHub. El nombre del repositorio debe seguir el formato Proyecto_BD_Avanzada_[NombreEquipo].
Invitación al Trainer: Se deberá invitar al "trainer" como colaborador al repositorio privado para que tenga acceso de lectura y pueda revisar el código. El nombre de usuario del trainer será proporcionado por él.
Estructura de Archivos: El repositorio deberá contener una estructura de archivos clara y ordenada. Todos los scripts deben estar en la raíz del repositorio.


Contenido del Archivo README.md
El archivo README.md es la portada del proyecto y debe contener la siguiente información:



Título del Proyecto: Proyecto de Base de Datos para un E-commerce.
Descripción Breve: Un párrafo que resuma el objetivo del proyecto.
Integrantes: Un listado con los nombres completos de los miembros del equipo.
Instrucciones de Ejecución: Una guía clara que indique el orden en que se deben ejecutar los archivos SQL para construir y probar la base de datos. Por ejemplo:
Ejecutar 01_Esquema_y_Datos.sql para crear la estructura y cargar los datos iniciales.
Ejecutar los scripts del 02 al 07 en orden para implementar toda la lógica avanzada.


Archivos SQL Individuales
El código del proyecto deberá estar segmentado en los siguientes archivos .sql para facilitar su revisión y ejecución. Cada archivo debe contener únicamente el código correspondiente a su nombre.



01_Esquema_y_Datos.sql
Contendrá todas las sentencias CREATE TABLE para definir la estructura completa de la base de datos.
Incluirá todas las sentencias INSERT INTO para poblar las tablas con los datos de ejemplo estandarizados.


02_Consultas_Avanzadas.sql
Contendrá las 20 consultas de análisis y reporteo. Cada consulta debe estar precedida por un comentario que explique la pregunta de negocio que responde (ej. -- 1. Top 10 Productos Más Vendidos).


03_Funciones.sql
Contendrá las 20 sentencias CREATE FUNCTION.


04_Seguridad.sql
Contendrá todas las sentencias para la creación de roles, usuarios y la asignación de permisos (CREATE ROLE, CREATE USER, GRANT).


05_Triggers.sql
Contendrá la sentencia CREATE TABLE para la tabla de auditoría (log_cambios_precio).
Incluirá las 20 sentencias CREATE TRIGGER.


06_Eventos.sql
Contendrá la sentencia CREATE TABLE para la tabla de reportes (reporte_ventas_semanales).
Incluirá la sentencia CREATE EVENT y el comando para activar el event_scheduler.


07_Procedimientos_Almacenados.sql
Contendrá las 20 sentencias CREATE PROCEDURE.