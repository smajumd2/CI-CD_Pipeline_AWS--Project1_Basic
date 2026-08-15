FROM tomcat:10.1-jdk17

# Remove default webapp and place custom index page

RUN rm -rf /usr/local/tomcat/webapps/ROOT
COPY index.html /usr/local/tomcat/webapps/ROOT/index.html

EXPOSE 8080
CMD [ "catalina.sh", "run"]