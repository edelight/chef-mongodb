#!/usr/bin/env bats

@test "starts mongodb" {
  # should return a 0 status code if mongodb is running
  /etc/init.d/mongodb status
}
