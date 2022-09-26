#!/usr/bin/perl

use warnings;
use strict;
use lib "/home/nagios/checkscripts";
use LinuxUtils;
use POSIX;

#### Variable Declaration ##
  my $type_ci=0;
  my $type_db=0;
  my $type_ai=0;
  my $final_type="";
  my $db_type="";
  my $file="/tmp/disk_usage.txt";
  my $file1="/tmp/usage.txt";
  my $file2="/tmp/disk_buff.txt";
  my $file3="/tmp/diff_disk.txt";
  my $file4="/sapmnt/dlm/services/servermgmnt/google/resources_saved";
  my $precentage_disk=0;
  my $total_disk=0;
  my $final_disk=0;
  my $final_disk1=0;
  my $disksize=0;
  my $a=0;
  my $b=0;
  my $total_disksize=0;
  my $precentage_disk1=0;
  my $total_disk1=0;
  my $final_disk2=0;
  my $precentage_cpu=0;
  my $total_cpu=0;
  my $final_cpu=0;
  my $precentage_memory=0;
  my $total_memory=0;
  my $total_memory1=0;
  my $final_memory=0;
  my $cpu_value=0;
  my $ram_value=0;
  my $used_size=0;
  my $final_buff=0;
  my $sapmnt_disk=0;
  my $logdir_disk=0;
  my $disk_logdir=0;
  my $disk_sapmnt=0;
  my $disk_saptemp=0;
  my $disk_saptrace=0;
  my $disk_origlog=0;
  my $cpu_diff=0;
  my $ram_diff=0;
  my $sapmnt_diff=0;
  my $logdir_diff=0;
  my $saptemp_diff=0;
  my $saptrace_diff=0;
  my $origlog_diff=0;
  my $total_buff=0;
  my $total=0;
  my $total_buff1=0;
  my $count_disk1=0;
  my $difference=0;
  my $count=0;
  my $fs=0;
`> $file3`;


my $hostname=`hostname`;
my $host=`hostname -f`;
chomp($hostname);
chomp($host);

#########SID Info #######
  my $sid_details=`grep ..adm /etc/passwd | cut -f1 -d ":"| egrep -v '^sap|^daa|^da1|^c3a|^d7a|^d7b|^d2b|^d2a|^tes'| cut -c1-3`;
  chomp($sid_details);
  my $sid= uc$sid_details;
  chomp($sid);
#  print "SID = $sid \n";

#########OS Info #######
 my @os_info = get_os_info('version vendor major_version patch_level');
        my $os_version = shift @os_info;
        my $os_vendor = shift @os_info;
        my $os_major_version = shift @os_info;
        my $os_patch_level = shift @os_info;

 my $os="$os_major_version".".$os_patch_level\n";
 chomp($os);
# print "Osrelease = $os\n";

#########type of server Info #######
  `grep lddb* /etc/sysconfig/network/ifcfg*`;
   if ($? eq 0){$type_db=1};
  `grep ldci* /etc/sysconfig/network/ifcfg*`;
   if ($? eq 0){$type_ci=1};
  `grep ldai* /etc/sysconfig/network/ifcfg*`;
  if ($? eq 0){$type_ai=1};
        if ($type_ci == 1 && $type_db == 1)
            {$final_type="SAPSYSTEM"}
        elsif($type_ci == 1)
            {$final_type="CI";}
        elsif($type_db == 1)
            {$final_type="DB"}
        elsif($type_ai == 1)
            {$final_type="AI";}
        elsif($type_ai == 0 && $type_db == 0){$final_type="SP";}
        chomp($final_type);

#print "Instance-Type = $final_type\n";

##### to get the peak usage of cpu and memory ######
  `curl -ks -u 'dlm:pw4remL#' 'https://nagios-api.zone1.mo.sap.corp/rest/rest.pl?lob=DLM&command=get_services&service_match=peak' | grep -i $hostname > $file1`;
#########CPU Calculation #######
  $precentage_cpu=`cat $file1 | awk -F'CPU peak usage at ' '{print \$2}' | awk -F"%" '{print \$1}' | awk 'NF > 0'`;
  $total_cpu=`cat /proc/cpuinfo | grep processor| tail -n1 |awk '{print \$3}'`;
  chomp($precentage_cpu);
  chomp($total_cpu);
  $total_cpu=$total_cpu+1;
  `echo cpu.total-$total_cpu >> $file3`;
      $cpu_value = (($precentage_cpu/100)*$total_cpu);
        $cpu_value= POSIX::ceil($cpu_value);

  chomp($cpu_value);
  #if ($cpu_value < 8){$cpu_value=8;}
  if (($cpu_value%2) != 0){$cpu_value++;}
if ($final_type eq "SAPSYSTEM"){$cpu_value=$cpu_value/2;}

#print "CPU = $cpu_value";

#########RAM Calculation #######
  $precentage_memory=`cat $file1 | awk -F'Memory peak usage at ' '{print \$2}' | awk -F"%" '{print \$1}' | awk 'NF > 0'`;
  $total_memory=`cat $file1 | awk -F'Memory: ' '{print \$2}' | awk '{print \$1}'|awk 'NF > 0'`;
  chomp($precentage_memory);
  chomp($total_memory);
        $ram_value = (($precentage_memory/100)*$total_memory);
        $ram_value= POSIX::ceil($ram_value);
  $total_memory1=$total_memory*1024;
  `echo ram.total-$total_memory1 >> $file3`;
  chomp($ram_value);
  if ($final_type eq "SAPSYSTEM"){$ram_value=$ram_value/2;}
  $ram_value=$ram_value*1024;
  my $ram_range1=range1($cpu_value);
  my $ram_range2=range2($cpu_value);
  my $ram_value2;
 #    print "Range1-$ram_range1 Range2-$ram_range2\n";
  if ($ram_value > $ram_range2){
     while ($ram_value > $ram_range2){
     $cpu_value= $cpu_value + 2;
        $ram_range1 =0;
        $ram_range2 =0;
        $ram_range1=range1($cpu_value);
        $ram_range2=range2($cpu_value);
        $ram_value2=ram_cal($cpu_value,$ram_range1,$ram_range2,$ram_value);
        }
        }
  else
   {$ram_value2=ram_cal($cpu_value,$ram_range1,$ram_range2);}
  my $ram=$ram_value2;
  my $cpu=$cpu_value;
#print "Ram=$ram and CPU=$cpu ";

`echo ram.final-$ram >> $file3`;
`echo cpu.final-$cpu >> $file3`;

#################CI Infromation##############
if($final_type ne "SAPSYSTEM" && $type_ci eq 1)
{
         $cpu_diff=diff_cal("cpu");
         $ram_diff=diff_cal("ram");
#        open(my $fh,'>>',$file4) or die $!;
#        print $fh "$host       $sid      $final_type             NA      $ram_diff   $cpu_diff       NA      NA      NA      NA                NA\n";
#        close $fh;
#        print "--ram=$ram --cpu=$cpu --osrelease=$os --sid=$sid --instancetype=$final_type \n";
}
#################AI Infromation##############
if($final_type ne "SAPSYSTEM" && $type_ai eq 1)
{
         $cpu_diff=diff_cal("cpu");
         $ram_diff=diff_cal("ram");
#        open(my $fh,'>>',$file4) or die $!;
#        print $fh "$host       $sid      $final_type             NA      $ram_diff   $cpu_diff       NA      NA      NA      NA                NA\n";
#        close $fh;
#        print "--ram=$ram --cpu=$cpu --osrelease=$os --sid=$sid --instancetype=$final_type \n";
}

#########DB type #######
if($type_db eq 1){

  `cat /etc/fstab | grep -i hana | grep -i $sid`;
        if ($? eq 0)
        {$db_type="S4Hana"};

  `cat /etc/fstab | grep -i hdb | grep -i $sid`;
        if ($? eq 0)
        {$db_type="Hana"};

  `cat /etc/fstab | grep -i sapdb | grep -i $sid`;
        if ($? eq 0)
        {$db_type="MaxDB";
         $disk_sapmnt=disk_cal("sapdata"); ##sapdata function call##
         $cpu_diff=diff_cal("cpu");
         $ram_diff=diff_cal("ram");
         $sapmnt_diff=diff_cal("sapdata");
        open(my $fh,'>>',$file4) or die $!;
        print $fh "$host         $sid    $final_type     $db_type        $ram_diff       $cpu_diff       $sapmnt_diff    NA      NA      NA                NA\n";
        close $fh;
        print "--ram=$ram --cpu=$cpu --osrelease=$os --sid=$sid --instancetype=$final_type --dbtype=$db_type --disksize=$disk_sapmnt \n";
        }

  `cat /etc/fstab | grep -i oracle | grep -i $sid`;
        if ($? eq 0)
        {$db_type="Oracle";
        $disk_sapmnt=disk_cal("sapdata"); ##sapdata function call##
        $disk_saptemp=disk_cal("saptemp");##saptemp function call##
        $disk_saptrace=disk_cal("saptrace");##saptrace function call##
        $disk_origlog=disk_cal("origlog");##origlog function call##
        $cpu_diff=diff_cal("cpu");
        $ram_diff=diff_cal("ram");
        $sapmnt_diff=diff_cal("sapdata");
        $saptemp_diff=diff_cal("saptemp");
        $saptrace_diff=diff_cal("saptrace");
        $origlog_diff=diff_cal("origlog");
        open(my $fh,'>>',$file4) or die $!;
        print $fh "$host                 $sid    $final_type     $db_type        $ram_diff       $cpu_diff       $sapmnt_diff    NA      $saptemp_diff   $saptrace_diff                 $origlog_diff \n";
        close $fh;
        print "--ram=$ram --cpu=$cpu --osrelease=$os --sid=$sid --instancetype=$final_type --dbtype=$db_type --disksize=$disk_sapmnt --tempdir=$disk_saptemp --tracedir=$disk_saptrace --logdir=$disk_origlog\n";
        };

  `cat /etc/fstab | grep -i db2 | grep -i $sid`;
        if ($? eq 0)
        {$db_type="db6";
         $disk_sapmnt=disk_cal("sapdata"); ##sapdata function call##
         $disk_logdir=disk_cal("log_dir");
         $cpu_diff=diff_cal("cpu");
         $ram_diff=diff_cal("ram");
         $sapmnt_diff=diff_cal("sapdata");
         $logdir_diff=diff_cal("log_dir");
         open(my $fh,'>>',$file4) or die $!;
         print $fh "$host        $sid      $final_type           $db_type        $ram_diff       $cpu_diff       $sapmnt_diff    $logdir_diff    NA      NA    NA \n";
         close $fh;
         print "--ram=$ram --cpu=$cpu --osrelease=$os --sid=$sid --instancetype=$final_type --dbtype=$db_type --disksize=$disk_sapmnt --logdir=$disk_logdir\n";
        }

  `cat /etc/fstab | grep -i sybase | grep -i $sid`;
        if ($? eq 0)
        {$db_type="Sybase";
         $disk_sapmnt=disk_cal("sapdata"); ##sapdata function call##
         $cpu_diff=diff_cal("cpu");
         $ram_diff=diff_cal("ram");
         $sapmnt_diff=diff_cal("sapdata");
         open(my $fh,'>>',$file4) or die $!;
         print $fh "$host       $sid      $final_type            $db_type        $ram_diff       $cpu_diff       $sapmnt_diff    NA      NA      NA            NA\n";
         close $fh;
         print "--ram=$ram --cpu=$cpu --osrelease=$os --sid=$sid --instancetype=$final_type --dbtype=$db_type --disksize=$disk_sapmnt \n";
        }
        }


#############Funcation###########
##### 1st Range Calc ##########
sub range1
{
 my $cup = shift;
 my $remainder1 = 0;
 my $memory_range1 = 0;
 my $ram_cal1=0.9*1024*$cpu_value;
 $ram_cal1 = int $ram_cal1;
 while ($remainder1 == 0){
                if (($ram_cal1%256)!=0) { $ram_cal1++; }
                else {$memory_range1=$ram_cal1;$remainder1 = 1;}
        }
  return $memory_range1;

}

##### 2nd Range Calc ##########
sub range2
{
 my $cup = shift;
 my $remainder2 = 0;
 my $memory_range2 = 0;
 my $ram_cal2=6.5*1024*$cpu_value;
 $ram_cal2 = int $ram_cal2;
 while ($remainder2 == 0){
                if (($ram_cal2%256)!=0) { $ram_cal2++; }
                else {$memory_range2=$ram_cal2;$remainder2 = 1;}
        }
  return $memory_range2;
}

sub ram_cal
{
 my $cup = shift;
 my $ram_range1 = shift;
 my $ram_range2 = shift;
 if ($ram_value < $ram_range1){$final_memory=$ram_range1;}
 elsif($ram_value >= $ram_range1 && $ram_value <= $ram_range2){
 my $remainder1 = 0;
 while ($remainder1 == 0){
                if (($ram_value%256)!=0) { $ram_value++; }
                else {$final_memory=$ram_value;$remainder1 = 1;}
       }
}
  return $final_memory;
}

sub diff_cal
{
my $val1 = shift;
my $val2=`cat $file3 |grep "$val1.total"| awk -F'-' '{print \$2}'`;
chomp $val2;
my $val3=`cat $file3 |grep -w "$val1.final"| awk -F'-' '{print \$2}'`;
chomp $val3;
my $val4=$val2-$val3;
#print $val4;

return $val4;
}

##sapdata function call##
sub disk_cal
{
 $fs = shift;
 $count_disk1=1;
 $final_disk1 =0;
 $total_buff=0;
 $total=0;
 $total_buff1=0;
        `df -h | grep "$fs" > $file`;
        `cat $file | grep -w "log_dir2"`;
        if ($? eq 0){$count=1;}
        else{$count=`cat $file | grep -i "$fs"| wc -l`;}
        chomp($count);
        for ( my $c=1; $c<=$count; $c++ )
        {
         $a=0;
         $b=0;
        $total_disk=`cat $file | awk '{print \$2}' | awk NR==$count_disk1`;
        chomp($total_disk) ;
        if ($total_disk =~ /T/){
           $total_disk=`cat $file | awk '{print \$2}' |awk -F'T' '{print \$1}'| awk NR==$count_disk1`;
           $total_disk=$total_disk*1024;}
         else
           {$total_disk=`cat $file | awk '{print \$2}' |awk -F'G' '{print \$1}'| awk NR==$count_disk1`;}
        if (($fs eq "log_dir") && ($total_disk<="12")){$total=12;}
        elsif(($fs eq "saptemp") && ($total_disk<="2")){$total=2;}
        elsif(($fs eq "saptrace") && ($total_disk<="2")){$total=2;}
        elsif(($fs eq "origlog") && ($total_disk<="5")){$total=5;}
        else{
        $precentage_disk=`cat $file | awk '{print \$5}'| awk -F"%" '{print \$1}' | awk NR==$count_disk1`;

        $used_size=`cat $file | awk '{print \$3}' |awk '{print \$1}'| awk NR==$count_disk1`;
         if ($used_size =~ /T/){
           $used_size=`cat $file | awk '{print \$3}' |awk -F'T' '{print \$1}'| awk NR==$count_disk1`;
           $used_size=$used_size*1024;}
         elsif ($used_size =~ /G/)
           {$used_size=`cat $file | awk '{print \$3}' |awk -F'G' '{print \$1}'| awk NR==$count_disk1`;}
         else{
           $used_size=`cat $file | awk '{print \$3}' |awk -F'M' '{print \$1}'| awk NR==$count_disk1`;
           $used_size=$used_size/1024;}
                $final_disk = (($precentage_disk/100)*$total_disk);
               $final_disk= POSIX::ceil($final_disk);
               $total_buff=(($used_size/0.9)-$used_size);
               $total_buff=POSIX::ceil($total_buff);
         $a = $final_disk;
         $final_disk1=$a+$final_disk1;
        $b=$total_buff;
        $total_buff1=$b+$total_buff1;
        }
        `echo "$fs.total-$total_disk" >> $file3`;
   $count_disk1++;
 }

if ($total==0){$total=$final_disk1+$total_buff;}
`echo "$fs.final-$total" >> $file3`;
return $total;
}
