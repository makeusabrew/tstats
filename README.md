# tstats

A quick and simple node.js script which connects to Twitter's "Sample" streaming API
and records a few statistics of interest, namely:

* favourites count
* followers count
* friends count

Every 30 seconds it writes out the 95th percentile for each of these stats.
