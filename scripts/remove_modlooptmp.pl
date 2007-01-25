#!/usr/local/bin/perl

($currentmonth,$currentday)=split(/\s+/,`/bin/date '+%m %d'`);
$currentmonth=int($currentmonth);
$removemonth=$currentmonth;
if ($currentday > 15) {
	$removeday = $currentday-15;
} else {
	$removeday=(30+$currentday)-15;
	$removemonth=$currentmonth-1;
}
print " $removeday,$removemonth\n";

@dirs=`/bin/ls -ld /diva2/home/andras/html/tmploop/do_modloop* |/usr/local/bin/awk '{print \$9,\$6,\$7}'`;
foreach $dir (@dirs) {
	chomp $dir;
	($dir,$month,$day)=split(/\s+/,$dir);
	$month=&number_date($month);	
	if ((($removeday>=$day) && ($removemonth >= $month)) || (($removeday>$day) && $removemonth>$month)) {
		print "removing $dir ($month, $day)\n";
		system("/bin/rm -rf $dir");
	}
}


sub number_date {

my %number;
my $month=$_[0];

$number{'Jan'}=1;
$number{'Feb'}=2;
$number{'Mar'}=3;
$number{'Apr'}=4;
$number{'May'}=5;
$number{'Jun'}=6;
$number{'Jul'}=7;
$number{'Aug'}=8;
$number{'Sep'}=9;
$number{'Oct'}=10;
$number{'Nov'}=11;
$number{'Dec'}=12;

return $number{$month};


}
