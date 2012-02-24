server = process.argv[5] || "127.0.0.1"

https = require "https"
redis = require("redis").createClient(6379, server)
percentile = require("./shared").percentile
require "colors"

throw "Please specify a username" unless process.argv[2]
throw "Please specify a password" unless process.argv[3]

desiredPc = process.argv[4] || 0.95

options =
    host: "stream.twitter.com"
    port: 443
    path: "/1/statuses/sample.json"
    headers:
        authorization: "Basic "+ new Buffer(process.argv[2]+":"+process.argv[3]).toString("base64")

processingStats = false
numStats = 0

redis.on "ready", ->

    redis.llen "tstats:favourites", (err, result) ->
        numStats = parseInt(result)
        connect()

connect = ->
    https.get options, (response) ->
        response.setEncoding "utf8"

        buffer = ""
        strpos = -1

        response.on "data", (chunk) ->
            buffer += chunk
            strpos = buffer.indexOf "\r"

            if strpos isnt -1
                data = buffer.substr 0, strpos
                if data.length > 1
                    if processingStats
                        process.stdout.write ".".yellow
                    else
                        handleData data

                buffer = buffer.substr(strpos+1)
            
        response.on "end", ->
            console.log "stream terminated"

# deal with a tweet
handleData = (data) ->
    try
        processed = JSON.parse data.toString("utf8")
    catch e
        console.log "Could not parse [#{data}]"
        return

    if not processed.user?
        process.stdout.write ".".red
        return

    stats =
        friends:    processed.user.friends_count
        followers:  processed.user.followers_count
        favourites: processed.user.favourites_count

    redis.rpush "tstats:friends", stats.friends
    redis.rpush "tstats:followers", stats.followers
    redis.rpush "tstats:favourites", stats.favourites
    numStats += 1

    process.stdout.write "."

processStats = ->
    processingStats = true

    numResults = 0
    favourites = 0
    followers  = 0
    friends    = 0

    checkWrite = ->
        numResults += 1
        if numResults is 3
            d = new Date()
            process.stderr.write "#{favourites}, #{followers}, #{friends}, #{numStats}, \"#{d.toString()}\"\n"
            process.stdout.write ".".green.inverse
            processingStats = false

    redis.lrange "tstats:favourites", 0, -1, (err, result) ->
        result.sort (a, b) ->
            return parseInt(a) - parseInt(b)

        favourites = percentile result, desiredPc
        checkWrite()

    redis.lrange "tstats:followers", 0, -1, (err, result) ->
        result.sort (a, b) ->
            return parseInt(a) - parseInt(b)
        
        followers = percentile result, desiredPc
        checkWrite()

    redis.lrange "tstats:friends", 0, -1, (err, result) ->
        result.sort (a, b) ->
            return parseInt(a) - parseInt(b)
        
        friends = percentile result, desiredPc
        checkWrite()

setInterval ->
    processStats()
, 30000

process.on "SIGINT", ->
    console.log "caught SIGINT"
    redis.quit()
    process.exit 0
