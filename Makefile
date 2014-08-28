START='http://dir.yahoo.com/computers_and_internet/communications_and_networking/home_networking/'
test:
	./spider.pl -t $(START)

clean:
	-rm spider.log urls.txt hosts.txt

