exports.percentile = (N, P) ->
    n = parseInt(Math.round(P * N.length + 0.5))
    if n > 1
        return N[n-2]
    return 0
