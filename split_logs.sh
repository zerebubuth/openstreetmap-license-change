#! /bin/bash

LOG_DIR="logs"
LOG_FILES=`find $LOG_DIR -name "*.log" \! -name "*-*"`

for file in $LOG_FILES
do
  echo "Splitting file $file"

  awk '
  {

    fname=gensub(".log$","","h",FILENAME);
    if (prev != fname) {
      header=""; sep=""; inhdr=1;
    }
    prev=fname;

    if (substr($3, 1, 1) == "#") {
      inhdr=0;
      pid=gensub("[]#]","","g",$3);
      if (!(pid in started)) {
        print header > fname "-" pid ".log"
        started[pid]=1;
      }
      print $0 > fname "-" pid ".log"
    } else {
      if (inhdr) {
        header=header sep $0;
        sep="\n";
      } else {
        print $0 > fname "-" pid ".log"
      }
  }}' $file
done

#echo removing old log files
#rm $LOG_FILES