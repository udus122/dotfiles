#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Daily Journal
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🪨
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description create a scribble file in obsidian
# @raycast.author udus
# @raycast.authorURL https://raycast.com/udus

open --background 'obsidian://advanced-uri?vault=notes&daily=true'
