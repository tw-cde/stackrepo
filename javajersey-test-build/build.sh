#!/bin/sh

set -eo pipefail

puts_red() {
    echo $'\033[0;31m'"      $@" $'\033[0m'
}

puts_red_f() {
  while read data; do
    echo $'\033[0;31m'"      $data" $'\033[0m'
  done
}

puts_green() {
  echo $'\033[0;32m'"      $@" $'\033[0m'
}

puts_step() {
  echo $'\033[0;34m'" -----> $@" $'\033[0m'
}

on_exit() {
    last_status=$?
    if [ "$last_status" != "0" ]; then
        if [ -f "process.log" ]; then
          cat process.log|puts_red_f
        fi

        if [ -n "$MYSQL_CONTAINER" ]; then
            echo
            puts_step "Cleaning ..."
            docker stop $MYSQL_CONTAINER &>process.log && docker rm $MYSQL_CONTAINER &>process.log
            puts_step "Cleaning complete"
            echo
        fi
        exit 1;
    else
        puts_green "build success"
        exit 0;
    fi
}

trap on_exit HUP INT TERM QUIT ABRT EXIT

CODEBASE_DIR=$CODEBASE
HOST_IP=$(ip route|awk '/default/ { print $3 }')

# echo
# puts_step "Launching baking services ..."
# MYSQL_CONTAINER=$(docker run -d -P -e MYSQL_USER=mysql -e MYSQL_PASSWORD=mysql -e MYSQL_DATABASE=appdb -e MYSQL_ROOT_PASSWORD=mysql hub.deepi.cn/mysql)
# MYSQL_PORT=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "3306/tcp") 0).HostPort}}' ${MYSQL_CONTAINER})
# export DATABASE="jdbc:mysql://$HOST_IP:$MYSQL_PORT/appdb?user=mysql&password=mysql"
# until docker exec $MYSQL_CONTAINER mysql -h127.0.0.1 -P3306 -umysql -pmysql -e "select 1" &>/dev/null ; do
#     echo "...."
#     sleep 1
# done
# puts_step "Complete Launching baking services"
# echo

cd $CODEBASE_DIR
# echo
# puts_step "Start migratioin ..."
# GRADLE_USER_HOME="$CACHE_DIR" gradle fC fM &> process.log
# puts_step "Migration complete"
# echo

# echo
# puts_step "Start test ..."
# GRADLE_USER_HOME="$CACHE_DIR" gradle test -i &> process.log
# puts_step "Test complete"
# echo

puts_step "Start generate standalone ..."
GRADLE_USER_HOME="$CACHE_DIR" gradle standaloneJar &>process.log
puts_step "Generate standalone Complete"

(cat  <<'EOF'
#!/bin/sh
# flyway migrate -url="$DATABASE" -locations=filesystem:`pwd`/dbmigration
# flyway migrate -url="$DATABASE" -locations=filesystem:`pwd`/initmigration -table="init_version" -baselineOnMigrate=true -baselineVersion=0
# nc -l -p 8088
java -jar app-standalone.jar
EOF
) > wrapper.sh

(cat << EOF
FROM hub.deepi.cn/jre-8.66:0.1
# RUN apk --update add tar
# ADD src/main/resources/db/migration dbmigration
# ADD src/main/resources/db/init initmigration
# RUN mkdir /usr/local/bin/flyway && \
#	  curl -jksSL https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/4.0/flyway-commandline-4.0.tar.gz \
#     | tar -xzf - -C /usr/local/bin/flyway --strip-components=1
# ENV PATH /usr/local/bin/flyway/:$PATH
ADD build/libs/app-standalone.jar app-standalone.jar
ADD wrapper.sh wrapper.sh
RUN chmod +x wrapper.sh
ENV APP_NAME $APP_NAME
EXPOSE 8088
CMD ["./wrapper.sh"]
EOF
) > Dockerfile

# (cat << EOF
FROM hub.deepi.cn/jre-8.66:0.1
# ADD build/libs/verify-standalone.jar verify-standalone.jar
# CMD ["java", "-jar", "verify-standalone.jar"]
# EOF
# ) > Dockerfile.verify

echo
puts_step "Building image ..."
docker build -t $IMAGE . &>process.log
puts_step "Building image $IMAGE complete "
echo

# echo
# puts_step "Building verify image ..."
# GRADLE_USER_HOME="$CACHE_DIR" gradle itestJar &>process.log
# docker build -f Dockerfile.verify -t $VERIFY_IMAGE . &>process.log
# puts_step "Building verify image $VERIFY_IMAGE complete"
# echo
