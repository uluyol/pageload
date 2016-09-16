
const fs = require('fs'),
	readline = require('readline'),
	ABPFilterParserLib = require('abp-filter-parser-cpp'),
	parseArgs = require('minimist'),
	jayson = require('jayson');

const ABPFilterParser = ABPFilterParserLib.ABPFilterParser
const FilterOptions = ABPFilterParserLib.FilterOptions

args = parseArgs(process.argv.slice(2), opts={
	default: {ads: true, tracking: false},
	boolean: ['ads', 'tracking']
});

const rl = readline.createInterface({
	input: process.stdin,
	output: process.stdout,
});

const parser = new ABPFilterParser()

if (args.ads) {
	parser.parse(fs.readFileSync('easylist.txt').toString());
}
if (args.tracking) {
	parser.parse(fs.readFileSync('easyprivacy.txt').toString());
}


var server = jayson.server({
	match: function(args, callback) {
		var results = [];
		for (var i=0; i < args.length; i++) {
			results.push(parser.matches(args[i].url, FilterOptions.ResourcesOnly, args[i].domain));
		}
		callback(null, results);
	}
});

server.http().listen(3000);
