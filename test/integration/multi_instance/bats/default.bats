#!/usr/bin/env bats

@test "starts configserver" {
    ps -ef | grep 'config /etc/mongodb-configserver.conf' | grep -v grep
}

@test "starts mongos" {
    ps -ef | grep 'config /etc/mongodb-mongos.conf' | grep -v grep
}
