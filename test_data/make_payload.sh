
perl -pe '$x = `date +%s`; chomp $x; $x %= 100000000; s/TIMESTAMP/$x/g; ' < test_data/mobile_server_request.adapted.json | ruby test_data/tester.rb  > test_data/mobile.ingestion.payload


