test:
	./spider.pl -t http://dir.yahoo.com/

clean:
	-rm spider.log urls.txt hosts.txt

