
var cheerio;
var request;

exports.getArticles = function (req, res, next) {
  cheerio = require('cheerio');
  request = require('request');

  request.get('https://news.ycombinator.com/', function (err, request, body) {
    var $ = cheerio.load(body);
    var links = [];
    $('.title a[href^="http"], a[href^="https"]').each(function () {
      links.push($(this));
    });
    res.render('articles', {
      title: 'Articles',
      links: links
    });
  });
};