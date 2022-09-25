#!/usr/bin/perl

################################################################################
# Authors:  Nirmal Jeet Singh (I356530)
# Release: 20th February 2020
# Version: v1.0.0
# Description: Maintain users in DLM_SM_COE team in git ORG (DLM-Org)
################################################################################


use strict;
use warnings;
use feature "say";
use lib "/home/nagios/checkscripts/";
use CaptureOutput qw/capture_exec/;
my $IDs = `curl --silent -u I320398:390c856f15140d74aa31747cb9f2d7ceb2ce1fcf \"https://github.wdf.sap.corp/api/v3/teams/11942/members?page=[1-9]\" |grep -i login| awk -F '\"' '{print \$4}' |egrep -v 'smgituser|CAM-CHANGE' >/tmp/sm_coe_users`;

my $date=`date +%Y%m%d%S`;
chomp($date);
my $fname = "/tmp/gitusers_check_". $date;

unless(-e $fname) {
open my $fc, ">", $fname;
close $fc;
}


if ( -z "/tmp/sm_coe_users" ){
        print "\nIds didn't fetched via curl command";
}
else {
        my $file = '/tmp/sm_coe_users';
        open(my $fh,'<',$file)
                or die "Could not open file \"$file\" $!\n";
        while (my $row = <$fh>) {
        chomp  ($row);

        my $check = "id -a $row |grep \'dlm_service_sm_coe\' >/dev/null || echo '<font color=\"red\">Invalid user found in DLM_SM_COE team, please check and delete.</font> <br/>    <b>Username:</b> $row'";
        my ($check_out,$ssh_err,$exit_code) = capture_exec("$check");

         open (FH, '>>', $fname) or die $!;
          print FH $check_out;
        close (FH);

}
close ($fh);

}

if ( -z $fname ) {
        system("echo 'All the users are valid and part of DLM_SM_COE team' >$fname");
}
my $subject = "Git users Audit";
my $from_addr = '"Git_user_check"';
my $htmlformat01 = `perl -i -ne 'print unless \$lines{\$_}++;' $fname`;
my $htmlformat0 = `awk -i inplace '{print \$0"<br/>"}' $fname`;
my $htmlformat1 = `sed -i '1i<html><body><font size="3">\' $fname`;
my $htmlformat2 = `echo "</font></body></html>" >> $fname`;
my $msg = `cat $fname`;
my $script_user = `echo \$USER`;

my $send_mail = "perl /home/adminhosts/mail/dlm_mail.pl --template /home/adminhosts/mail/dlm_template.html --subject \"$subject\" --var 'headline=DLM - Git User Scanner' --var \"$msg\" --from '$from_addr' --to='DL_6124EEFEA7AE7A0280E7B908\@global.corp.sap'";
#my $send_mail = "perl /home/adminhosts/mail/dlm_mail.pl --template /home/adminhosts/mail/dlm_template.html --subject \"$subject\" --var 'headline=DLM - Git User Scanner' --var \"$msg\" --from '$from_addr' --to='i356530\@exchange.sap.corp'";
system ($send_mail);

my $remove_file = `rm -f $fname`;
my $remove_file1 = `rm -f /tmp/sm_coe_users`;
