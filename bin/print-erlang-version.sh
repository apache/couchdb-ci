#!/usr/bin/env bash

erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'  -noshell
