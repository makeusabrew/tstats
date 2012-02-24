server = process.argv[2] || "127.0.0.1"

redis = require("redis").createClient(6379, server)
percentile = require("./shared").percentile
require "colors"

redis.on "ready", ->
    favourites = 0
    followers  = 0
    friends    = 0

    console.log "fetching data..."
    numResults = 0
    checkWrite = ->
        numResults += 1
        if numResults is 3
            console.log "sample size: #{favourites.length}"
            analyse(favourites, followers, friends)

    redis.lrange "tstats:favourites", 0, -1, (err, result) ->
        result.sort (a, b) ->
            return parseInt(a) - parseInt(b)

        favourites = result
        checkWrite()

    redis.lrange "tstats:followers", 0, -1, (err, result) ->
        result.sort (a, b) ->
            return parseInt(a) - parseInt(b)
        
        followers = result
        checkWrite()

    redis.lrange "tstats:friends", 0, -1, (err, result) ->
        result.sort (a, b) ->
            return parseInt(a) - parseInt(b)
        
        friends = result
        checkWrite()

analyse = (favourites, followers, friends) ->

    process.stdin.on "data", (data) ->
        pc = data.toString() / 100.0
        console.log percentile(favourites, pc), percentile(followers, pc), percentile(friends, pc)
        question()

    question = ->
        process.stdin.resume()
        process.stdout.write "percentile? (0-100): "

    question()

process.on "SIGINT", ->
    console.log "caught sigint"
    redis.quit()
    process.exit 0
