#!/usr/bin/perl
use strict;
use warnings;
use JSON::MaybeXS ();
use Data::Dumper;

print "\n--- CDLI parser (v.0.13) ---\n";
print "This program generates KWIC indexes from CDLI transliterations\n";
print "--- Use: 1. search for all texts from a given period on CDLI (ex.: Uruk)\n";
print "---      2. click on \"download all texts\" within CDLI results page\n";
print "---      3. save file as \"CDLI_results.txt\" in a sub-folder named input_CDLI\n";
print "The program assumes that the following sub-folders exist in the working folder:\n";
print " data\n";
print " images\n";
print " input_CDLI\n";
print " json\n";
print " templates\n";


my $path = 'C:\Users\MyFolder'; #to be adjusted to your working directory
my $datapath = 'data\\';
my $inputdir = '\input_CDLI';
my $jsonpath = 'json\\';

chdir $path or die "Impossible to navigate to $path: $!\nProgram terminated prematurely\n";

my %roman_hash = (
  '1' => 'i',
  '2' => 'ii',
  '3' => 'iii',
  '4' => 'iv',
  '5' => 'v',
  '6' => 'vi',
  '7' => 'vii',
  '8' => 'viii',
  '9' => 'ix',
  '10' => 'x',
  '11' => 'xi',
  '12' => 'xii',
  '13' => 'xiii',
  '14' => 'xiv',
  '15' => 'xv',
  '16' => 'xvi',
  '17' => 'xvii',
  '18' => 'xviii',
  '19' => 'xix',
  '20' => 'xx',
  '21' => 'xxi',
  '22' => 'xxii',
  '23' => 'xxiii',
  '24' => 'xxiv',
  '25' => 'xxv',
  '26' => 'xxvi',
  '27' => 'xxvii',
  '28' => 'xxviii',
  '29' => 'xxix',
  '30' => 'xxx',
  '31' => 'xxxi',
  '32' => 'xxxii',
  '33' => 'xxxiii',
  '34' => 'xxxiv',
  '35' => 'xxxv',
  '36' => 'xxxvi',
  '37' => 'xxxvii',
  '38' => 'xxxviii',
  '39' => 'xxxix',
  '40' => 'iv'  
);

chdir $path.$inputdir or die "Impossible to navigate to $path$inputdir: $!\nProgram terminated prematurely\n";

my $input;

{
  local $/; #Enable 'slurp' mode
  open (my $fh, "<", "CDLI_results.txt") || die "Error opening the CDLI results file!:$!\n\n";;
  $input = <$fh>;
  close $fh;
}

chdir $path or die "Impossible to navigate to $path: $!\nProgram terminated prematurely\n";
my @texts = split /(?=Primary publication:)/, $input; #this implies that the string "Primary publication" marks the beginning of the text


#open output files
open(OUT, ">OUTPUT.tab") || die "Error creating the output file!: $!\n\n";
open(WARNINGS, ">warnings.txt") || die "Error creating the warnings file!\n\n";

print "Analyzing transliterations, please wait...\n";

my %hash_data = ();
my %geo_hash = ();
my %count_tot_freq = ();
my %count_genre_freq = ();
my %count_period_freq = ();
my %context_hash = ();
my %count_context = ();
my %hash_clusters = ();
my %hash_clusters_no_variants = ();
my %ref_hash = ();

my %final_freq_hash = ();
my %final_translit_hash = ();
my %final_cluster1_hash = ();
my %final_cluster2_hash = ();
my %cross_clusters_hash = ();

my %statistics = ();
my %warnings = ();
my %texts_without_transliteration = ();
my %texts_without_linguistic_content = ();
my %graphemic_oddities = ();
my $total_input_texts = 0;
print "Processing texts ...\n";
for (my $i=0;$i<=$#texts;$i++) {
    my $text = $texts[$i];
    $text =~ s/\n\n/\n/sg;
    my ($catalogue_entry, $transliteration) = split /(?<=Transliteration:)/, $text;
    
    $catalogue_entry =~ s/\n\n\s+/ /sg;#fix random carriage returns, ex: CDLI\n no.: P001836
    
    if ($catalogue_entry !~ m/^[A-z]/) { 
      next
    } else {
      $total_input_texts++;
    }
    
    if (!$catalogue_entry) {
      my $error = "\nCATALOGUE ERROR: text no. $i in the input list has no catalogue information. Text:\n$text\n"; 
      $warnings{'no_catalogue'}{$error}++;
      print "$error\n";
      next;
    }

    
    my ($CDLI_no) = $catalogue_entry =~ m/CDLI no.: (.+)/m;
    if (!$CDLI_no) {
        ($CDLI_no) = $transliteration =~ m/&(P\d+)/m;
    }
    
    if (!$CDLI_no) {
        print "===\nFATAL ERROR:\n--------catalogue--------:$catalogue_entry\n--------transliteration:$transliteration\n=========\ntext:\n$text\n========EXIT\n";
        exit 0;    
    }
    
    
    my @lines = split /\n/, $catalogue_entry;
    foreach my $line (@lines) {
        chomp $line;
        $line =~ s/^\s+|\s+$//;
        next if (!$line);
        next if ($line =~m/^\n/);
       
        my ($data_type, $datum) = split /: /, $line;
        $data_type =~ s/^\s+|\s+$// if ($data_type);
        $datum =~ s/^\s+|\s+$// if ($datum);
        if (!$data_type) {
            $data_type = '[NO_DATA_TYPE]';
        }
        if (!$datum) {
            $datum = '-';            
        }
        
        $hash_data{$CDLI_no}{$data_type}{$datum}++;
    }
    
    
    my @prov = keys %{$hash_data{$CDLI_no}{'Provenience'}};
    my @gen = keys %{$hash_data{$CDLI_no}{'Genre'}};
    my @per = keys %{$hash_data{$CDLI_no}{'Period'}};
    if (!$prov[0]) {
        $prov[0] = 'uncertain';
    }
    my $question_mark = "";
    if ($prov[0] =~ m/\?/) {
        $question_mark = '?';
    }
    
    if ($prov[0] =~m /uncertain \(mod\. uncertain\)/) {
        $prov[0] = 'uncertain';
        if ($question_mark) {
            $prov[0] = $prov[0].$question_mark;
        }
    }
    if ($prov[0] =~m /uncertain \(mod\. (.+)\)/) {
        $prov[0] = $1;
        if ($question_mark) {
            $prov[0] = $prov[0].$question_mark;
        }
    }
    if (!$gen[0]) {
        $gen[0] = 'uncertain';
    }
    
    
    $statistics{'provenance'}{$prov[0]}++;
    $statistics{'genre'}{$gen[0]}++;
    $statistics{'period'}{$per[0]}++;
    $statistics{'provenance2'}{$prov[0]}{$CDLI_no}++;
    
    #check 1 for texts without transliteration 
    $transliteration =~ s/^\s+|\s+$// if ($transliteration);
    if (!$transliteration) {
        $transliteration = '[NO_TRANSLITERATION]';
        $texts_without_transliteration{$CDLI_no}++;
        next;
    }
    $transliteration =~ s/\n\s+/ /s;#fix random carriage returns
    my @lines_trans = split /\n+/, $transliteration;
    #check 2 for texts without linguistic content, or not transliterated but with annotations
    my %test_trans = ();
    foreach my $line (@lines_trans) {
      chomp $line;
        $line =~s/^\s+|\s+$//;
        next if (!$line);
        next if ($line =~ m/^\@/);
        next if ($line =~ m/^\$/);
        next if ($line =~ m/^\#/);
        next if ($line =~ m/^\&/);
        $test_trans{$CDLI_no}++;
    }
    
    if (!exists $test_trans{$CDLI_no}) {
      $texts_without_linguistic_content{$CDLI_no}++;
      next;
    }
    
    $statistics{'texts'}{$CDLI_no}++;
    $statistics{'total_texts_with_transliteration'}++;
    
    my $object_type = ""; #@tablet, @envelope, @prism, @object
    my $obv_rev = "";
    my $column = "";
    my $seal = "";
    my $surface = "";
    my $annotation = "";
    my $line_num = "";
    my $other = "";
    
    foreach my $line (@lines_trans) {
        chomp $line;
        $line =~s/^\s+|\s+$//;
        next if (!$line);
        my $clean_tr = "";
        
        if ($line =~ m/\@tablet/) {
           $object_type = "tablet";
           next
        }
        if ($line =~ m/\@envelope/) {
           $object_type = "envelope";
           next
        }
        if ($line =~ m/\@prism/) {
           $object_type = "prism";
           next
        }
        if ($line =~ m/\@object/) {
           $object_type = $line;
           next
        }
        if ($line =~ m/\@obv/) {
           $obv_rev = "obv.";
           next
        }
        if ($line =~ m/\@rev/) {
           $obv_rev = "rev.";
           next
        }
        if ($line =~ m/\@left/) {
           $obv_rev = "le.";
           next
        }
        if ($line =~ m/\@right/) {
           $obv_rev = "re.";
           next
        }
        if ($line =~ m/\@top/) {
           $obv_rev = "top";
           next
        }
        if ($line =~ m/\@bottom/) {
           $obv_rev = "bt.";
           next
        }
        if ($line =~ m/\@column (.+)$/) {
            $column = $1;
            $column =~ s/^\s+|\s+$//;
            next
        }
        if ($line =~ m/^\@seal\s*\d*$/) {
            $obv_rev = $line;
            $obv_rev =~ s/^\s+|\s+$//;
            next
        }
        if ($line =~ m/^\@surface/) {
            $obv_rev = $line;
            $obv_rev =~ s/^\s+|\s+$//;
            next
        }
        if ($line =~ m/^\$/) {
            $annotation = $line;
            next
        }
        if ($line =~ m/^\#/) {
            $other = $other.$line.'--';
            next
        }
        if ($line =~ m/^&/) {#skips CDLI_no line
            next
        }
        
        if (($line) && ($line =~ m/^(\d.+?) (.+)$/)) {
            my $line_num = $1;
            my $tr_line = $2;
            $tr_line =~s/^\s+|\s+$//;
            my $refx = $surface.'.'.$obv_rev.'.'.$seal.'.'.$column.'.'.$line_num;
            $refx =~s/^\.//;
            $refx =~ s/\.\.+/\./g;
            $refx =~s/\.$//;
            $line_num =~ s/\.$//;
            $line_num =~ s/^\s+|\s+$//;
          
            $clean_tr = $tr_line;
            $clean_tr =~s /#//g;
            $clean_tr =~s /\?//g;
            $clean_tr =~s /\!//g;
            
            $statistics{'total_lines'}++;
            
            my @tokens = split /\s+/, $clean_tr;
            foreach my $token (@tokens) {
                
                $token =~ s/^\s+|\s+$//;
                $token =~ s/#//g;
                $token =~ s/\!//g;
                $token =~ s/\[|\]//g;
                $token =~ s/\<+|\>+//g;
                $token =~ s/^,|,$//;
                
                ### this has implications on how the text is to be interpreted. Change (LAGAB~b -> LAGAB~b as resulting from the line (LAGAB~b |DUxDISZ| ERIM~a)a

                $token =~ s/^\(//;
                $token =~ s/\)\w$//;
                next if ($token =~ m/^\d.*\.$/); #skips unwanted tokens such as 3.a.
                next if ($token =~ m/^0\d\d$/); #skips unwanted tokens such as 003
                
                next if (!$token);                   
                $statistics{'total_tokens'}++;
                my @genre = keys %{$hash_data{$CDLI_no}{'Genre'}};
                my @period = keys %{$hash_data{$CDLI_no}{'Period'}};
                
                $geo_hash{$token}{$genre[0]}{$CDLI_no}{$obv_rev}{$column}{$line_num}{$line}++;###$surface.'.'.$obv_rev.'.'.$seal.'.'.$column.'.'.$line_num
                $count_tot_freq{$token}++;
                $count_genre_freq{$token}{$genre[0]}++;
                $count_period_freq{$token}{$period[0]}++;
                $context_hash{$token}{$clean_tr}{$CDLI_no.' '.$refx}{$genre[0]}++;             
                              
                my @clean_array = split /\s+/, $clean_tr;
                my %clean_cluster = ();
                my %clean_cluster_no_variants = ();
                foreach my $clean_token (@clean_array) {
                  next if $clean_token =~ m/^\d/;
                  next if $clean_token =~ m/^,/;
                  next if $clean_token =~ m/^;/;
                  next if $clean_token =~ m/^X$/;
                  next if $clean_token =~ m/\.\.\./;
                  $clean_cluster{$clean_token}++;
                  $clean_token =~ s/\~\w\d*//g;
                  $clean_cluster_no_variants{$clean_token}++;
                }
                
                next if (scalar keys %clean_cluster < 2);#this is to say that clusters must be composed of at least 2 elements (numbers get removed from clusters)
                my $final_cluster = join ' ', sort keys %clean_cluster;
                $hash_clusters{$token}{$final_cluster}{$CDLI_no.' '.$refx}++;
                
                
                my $final_cluster_no_variants = join ' ', sort keys %clean_cluster_no_variants;
                $hash_clusters_no_variants{$token}{$final_cluster_no_variants}{$CDLI_no.' '.$refx}++;
                
                next if ($token eq ',');
                next if ($token eq ';');
                next if ($token eq 'X');
                next if ($token =~m /\.\.\./);
                next if ($token =~m /^\d/);
                $cross_clusters_hash{$final_cluster_no_variants}{$final_cluster}{$CDLI_no.' '.$refx}{$token}++;
                
                
            }
            
            $count_context{$clean_tr}++;
                  
            next
        } elsif ($line =~ m/\>Q\d+/) {#skip Q-lines for composites
            #...
        } elsif ($line =~ m/\>>/) {#skips cross-refereces lines
          #...
        } else {
            print "unexpected line: -->>$line<<--\n" if ($line !~m/^\s+$/);
            print WARNINGS "unexpected line: -->>$line<<--\n" if ($line !~m/^\s+$/);
        }
        
        
        

    }
    
}


print "... Processing textual tokens ...\n";
foreach my $token (sort keys %geo_hash) {
    next if ($token eq ',');
    next if ($token eq ';');
    next if ($token =~m /\.\.\./);
    next if ($token eq 'X');
    print OUT "$token\t";
    print OUT "total freq: $count_tot_freq{$token}x\n";
 
    my $g_count = 1;
    foreach my $gen_freq (sort keys %{$count_genre_freq{$token}}) {
      print OUT "$gen_freq: $count_genre_freq{$token}{$gen_freq}x\n";
      $final_freq_hash{$token}{$g_count} = "$gen_freq: $count_genre_freq{$token}{$gen_freq}x";
      $g_count++;
    }
    $g_count++;
    $final_freq_hash{$token}{$g_count} = 'Total freq.:'.$count_tot_freq{$token}.'x';
    print OUT "\t";
    foreach my $gen (sort keys %{$geo_hash{$token}}) {   
      foreach my $t_num (keys %{$geo_hash{$token}{$gen}}) {
          my @obvrev = sort keys %{$geo_hash{$token}{$gen}{$t_num}};
          for (my $i=0;$i<=$#obvrev;$i++) {
              my $o_r = $obvrev[$i];
              
              my @cols = sort {($a =~ /(\d+)/)[0] <=> ($b =~ /(\d+)/)[0]} keys %{$geo_hash{$token}{$gen}{$t_num}{$o_r}};
              for (my $k=0;$k<=$#cols;$k++) {
                  my $col = $cols[$k];
                  my $roman_col = $roman_hash{$col};
                  my @line_nums = sort {($a =~ /(\d+)/)[0] <=> ($b =~ /(\d+)/)[0]} keys %{$geo_hash{$token}{$gen}{$t_num}{$o_r}{$col}};
                  my $l_nums = join ',', @line_nums;
              }
          }
      }
    }
    
    #sort by frequency then by transliteration
    foreach my $clean_tr (sort {scalar (keys %{$context_hash{$token}{$b}}) <=> scalar (keys %{$context_hash{$token}{$a}}) || $a cmp $b} keys %{$context_hash{$token}}) {
      my @CDLI_refs = sort (keys %{$context_hash{$token}{$clean_tr}});
      my $freq_tr = scalar @CDLI_refs;
      $final_translit_hash{$token}{$freq_tr}{$clean_tr} = [ @CDLI_refs ];
    }
    
    
    foreach my $clean_tr (sort {scalar (keys %{$hash_clusters{$token}{$b}}) <=> scalar (keys %{$hash_clusters{$token}{$a}}) || $a cmp $b} keys %{$hash_clusters{$token}}) {
      my @CDLI_refs = sort (keys %{$hash_clusters{$token}{$clean_tr}});
      my $freq_tr = scalar @CDLI_refs;
      $final_cluster1_hash{$token}{$freq_tr}{$clean_tr} = [ @CDLI_refs ];
      foreach my $cdli_num (@CDLI_refs) {
      }
    }
    
 
    foreach my $clean_tr (sort {scalar (keys %{$hash_clusters_no_variants{$token}{$b}}) <=> scalar (keys %{$hash_clusters_no_variants{$token}{$a}}) || $a cmp $b} keys %{$hash_clusters_no_variants{$token}}) {
      my @CDLI_refs = sort (keys %{$hash_clusters_no_variants{$token}{$clean_tr}});
      my $freq_tr = scalar @CDLI_refs;
      $final_cluster2_hash{$token}{$freq_tr}{$clean_tr} = [ @CDLI_refs ];
      foreach my $cdli_num (@CDLI_refs) {
      }
    }  
}

### CROSS CLUSTER CHECK ###
my %noteworthy_variations = ();
print "\n... crossing clusters data ...\n";
foreach my $cluster_nv (sort keys %cross_clusters_hash) {
  my @clusters = sort keys %{$cross_clusters_hash{$cluster_nv}};
  if (scalar @clusters > 1) {
    my %interesting_tokens = ();
    for (my $i=0;$i<=$#clusters;$i++) {
      my $cluster = $clusters[$i];
      my @CDLI_nums = sort keys %{$cross_clusters_hash{$cluster_nv}{$cluster}};
      foreach my $CDLI_num (@CDLI_nums) {
        foreach my $token (sort keys %{$cross_clusters_hash{$cluster_nv}{$cluster}{$CDLI_num}}) {
          $noteworthy_variations{$token}{$cluster}{$CDLI_num}++;
          for (my $j=$i+1;$j<=$#clusters;$j++) {
            my $cluster2 = $clusters[$j];
            my @CDLI_nums2 = sort keys %{$cross_clusters_hash{$cluster_nv}{$cluster2}};
            foreach my $CDLI_num2 (@CDLI_nums2) {
              $noteworthy_variations{$token}{$cluster2}{$CDLI_num2}++;
              foreach my $token2 (sort keys %{$cross_clusters_hash{$cluster_nv}{$cluster2}{$CDLI_num2}}) {
                $noteworthy_variations{$token}{$cluster2}{$CDLI_num2}++;
                $noteworthy_variations{$token2}{$cluster}{$CDLI_num}++;
                $noteworthy_variations{$token2}{$cluster2}{$CDLI_num2}++;         
              }
            }
          }
        }
      }
    }
  }
}


my %final_variations_hash = ();
my %token_ranking = ();
foreach my $token (keys %noteworthy_variations) {
  my $ranking = 0;
  foreach my $cluster (keys %{$noteworthy_variations{$token}}) {
    foreach my $CDLI_num (keys %{$noteworthy_variations{$token}{$cluster}}) {
      $token_ranking{$token}++; 
    }
  }
  foreach my $cluster (keys %{$noteworthy_variations{$token}}) {
    foreach my $CDLI_num (keys %{$noteworthy_variations{$token}{$cluster}}) {
      my $final_rank = $token_ranking{$token};
      $final_variations_hash{$token}{$final_rank}{$cluster}{$CDLI_num}++; 
    }
  }
}



#images data
print "... working on images ...\n";
my $img_path = $path.'\images';
chdir $img_path or print "\n==========\nNO IMAGE FOLDER DETECTED, expected $img_path: $!\n==========\n";

my %hash_img_files = ();
my %hash_img2 = ();
my @filelist = glob ("*.png");
foreach my $file (sort @filelist) {
    #print "FILE:$file\n";
    if ($file=~ m/(.+?)(\.png)$/) {
        my $filename = $1;
        my $extension = $2;
        if ($filename =~m/^(.+?)_(P\d+.+?)__(.+)$/) {
            my $sign_name_file = $1;
            my $P_num_file = $2;
            my $ref = $3;
            $sign_name_file =~ s/--/~/g;
            $sign_name_file =~ s/'//g;
            if ($P_num_file =~ m/(P\d+)\D/) {
                $P_num_file =$1;
            }
            my $Pnumref = $P_num_file.' '.$ref;
            $hash_img_files{$sign_name_file}{$Pnumref} = $file;
            $hash_img2{$sign_name_file}{$file}++;
            #print "\t\t>>$Pnumref<<\n";
            
        } else {
          print "---WARNING: malformed image filename: $filename\n";
        }
        
    } else {
      print "SKIPPED FILE:$file\n";
    }   
}



#GRAPHEMICS
#STEP 1
#my $splitting_chars = '\.|\+|\&|[^~]x|%|\(|\)|\|';
print "... graphemic analysis ...\n";
my $splitting_chars = '\.|\+|\&|x|%|\(|\)|\|';
my %graphemic_hash = ();
foreach my $sign (keys %context_hash) {
  chomp $sign;
  #mask numbers
  my $sign_backup = $sign;
  $sign_backup =~s/(\d)\((.+?)\)/$1\[\[$2\]\]/g;
  my @sp = split "$splitting_chars", $sign_backup;
  foreach my $s (@sp) {
    $s =~ s/^\s+|\s+$//;
    $s =~ s/^\|+|\|+$//;
    $s =~ s/^\(|\)$// if ($s !~ m/^\d/);
    $s =~ s/\)~\w?$//;#NA2~a)~d -> NA2~a
    $s =~ s/\)//g;
    $s =~ s/\(//g;
    $s =~ s/\|//g;
    #$s =~ s/\)\)$//;#1(N57))) -> 1(N57)
    #$s =~ s/^\(//;#(HI -> HI
    $s =~s/(\d)\[\[(.+?)\]\]/$1\($2\)/g;;#un-mask numbers
    next if ($s =~m/^~\w\w?$/);
    next if (!$s);
    next if ($s=~ m/~x$/);#skips ZA~x as in ZA~x(|3(N57).(NI~a@gx1(N04))|), where the indication in parenthesis describes the sign being processed
    $s = $s.'x' if ($s =~ m/~$/);#workaround for restoring ZA~x instead of ZA~, NB: x is a splitting graph
    $graphemic_hash{$sign}{$s}++ if ($sign ne $s);
  }
}

#STEP2
my $regex = qr/
        (                   # start of bracket 1
        <                   # match an opening angle bracket
            (?:
                [^<>]++     # one or more non angle brackets, non backtracking
                  |
                (?1)        # recurse to bracket 1
            )*
        >                   # match a closing angle bracket
        )                   # end of bracket 1
        /x;

$" = "\n\t";

foreach my $sign (keys %context_hash) {
    my @queue = $sign;
    for (my $i=0;$i<=$#queue;$i++) {
    
        #mask numbers
        $queue[$i] =~s/(\d)\((.+?)\)/$1\[\[$2\]\]/g;
        $queue[$i] =~ s/\(/</g;
        $queue[$i] =~ s/\)/>/g;
        
        #skips ZA~x(|3(N57).(NI~a@gx1(N04))|)
        ## this assumes that the ~x are not nested in transliteration,
        ## i.e. there is no such thing as SIGN1~x(|SIGN2~x.SIGN3|),
        ## in which case SIGN2~x wont be processed in the loop below
        if ($queue[$i] =~ m/\~x\W/) {
            splice @queue, $i, 1;
            $i--
        };
    }

    my $c = 0;
    while( @queue ) {
        my $string = shift @queue;    
        #my $string_backup = $string;
        #print "--- $string\n";
        my @groups = $string =~ m/$regex/g;
        my @groups_backup = @groups;
        foreach my $group_back (@groups_backup) {
            $group_back =~ s/^\s+|\s+$//;            
            $group_back =~ s/</(/g;
            $group_back =~ s/>/)/g;
            $group_back =~ s/^\(//;
            $group_back =~ s/\)$//;
            $group_back =~s/(\d)\[\[(.+?)\]\]/$1\($2\)/g;#un-mask numbers

            $graphemic_hash{$sign}{$group_back}++ if ($sign ne $group_back);
        }
        unshift @queue, map { s/^<//; s/>$//; $_ } @groups;
    }
}

#STEP 3: cross-referencing

foreach my $sign (keys %graphemic_hash) {
  foreach my $related (keys %{$graphemic_hash{$sign}}) {
    $graphemic_hash{$related}{$sign}++;
  }
}

print "... generating HTML files ...\n";


chdir $path or die "Impossible to navigate back to $path: $!\nProgram terminated prematurely\n";

#index
open(INDEX, ">index.html") || die "Error creating the index html file!: $!\n\n";
print INDEX '
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>

<STYLE>
html,body{
  width: 100%;
  height: 100%;
}
body {
  font-family: Verdana, sans-serif;
  font-size: 10.5pt;
  line-height: 12pt;
  overflow-y: hidden;
  overflow-x: hidden;
  margin: 0;
}
.mainContainer {
	align:center;
	width:100%;
	height:88%;
}
h1 {
  text-align: center;
  font-size:150%;
}
.aParent {
  background-color: #f7f5e7;
  color: #000000;
  text-decoration: none;
  overflow: hidden;
}
.title {
  background-color: #f7f5e7;
  color: #000000;
  font-size: 17px;
  padding: 14px 16px;
  text-decoration: none;
  overflow: hidden;
  float: left;
  width: 35%
}
.left {
	align:left;
	width:15%;
	height:88%;
}
.middle {
	align:center;
	width:82%;
	height:88%;
}
.right {
	align:right;
	width:4%;
	height:88%;
}
/* Add a black background color to the top navigation */
.topnav {
  background-color: #f7f5e7;
  overflow: hidden;
  float: right;
  width: 60%
}

/* Style the links inside the navigation bar */
.topnav a {
  float: left;
  color: #000000;
  text-align: center;
  padding: 14px 16px;
  text-decoration: none;
  font-size: 17px;
}

/* Change the color of links on hover */
.topnav a:hover {
  background-color: #00fff7;
  color: black;
}

/* Add a color to the active/current link */
.topnav a.active {
  background-color: #4CAF50;
  color: white;
}
</STYLE>
<title>WritEMe archaic texts graphemic database</title>
</head>
<body>
<div class = "aParent">
  <div class="title"><b>Writing and Accounting in Early Mesopotamia</b><br> - Archaic Texts Graphemic Database</div>
  <div class="topnav">
    <a href="index.html">Home</a>
    <a href="db_container.html" target="mainContainer">Database</a>
    <a href="readme.html" target="mainContainer">README</a>
    <a href="statistics.html" target="mainContainer">Statistics</a>
    <a href="download.html" target="mainContainer">Download</a>
    <a href="https://github.com/MMaiocchi/WritEMe_database" target="_blank">GitHub</a>
    <a href="https://writeme.hypotheses.org" target ="_blank">Project</a>
  </div>
</div>
<iframe class="mainContainer" src="homepage.html" name="mainContainer" onload="autoResize(this)" marginwidth="0"  marginheight="0"  hspace="0"  vspace="0"  frameborder="0"></iframe>

</body>
</html>
';
close INDEX;

#db_container
open(DB_CONT, ">db_container.html") || die "Error creating the db_container html file!: $!\n\n";
print DB_CONT '
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <STYLE>
      html,body{
        width: 100%;
        height: 100%;
      }
      body {
        font-family: Verdana, sans-serif;
        font-size: 10.5pt;
        line-height: 12pt;
        overflow-y: hidden;
        overflow-x: hidden;
        margin: 0;
      }
      .left {
        align:left;
        width:15%;
        height:100%;
      }
      .middle {
        align:center;
        width:82%;
        height:100%;
      }
    </STYLE>
  </head>
  <body>
    <iframe class="left" src="signs.html" name="left" onload="autoResize(this)" marginwidth="0"  marginheight="0"  hspace="0"  vspace="0"  frameborder="0"></iframe>
    <iframe class="middle" src="db_default.html" name="middle" onload="autoResize(this)" marginwidth="0"  marginheight="0"  hspace="0"  vspace="0"  frameborder="0"></iframe>
  </body>
</html>
';
close DB_CONT;

#db_default
open(DB_DEF, ">db_default.html") || die "Error creating the db_default html file!: $!\n\n";
print DB_DEF '
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <title>WritEMe database - default</title>
    <STYLE>
      html,body{
        width: 100%;
        height: 100%;
      }
      body {
        font-family: Verdana, sans-serif;
        font-size: 10.5pt;
        line-height: 12pt;
        margin: 0;
      }
    </STYLE>
  </head>
  <body>
    <p>Please click on an item on the left panel. Use the search function to filter the list.</p>
  </body>
</html>
';
close DB_DEF;


#Signs -- left panel
open(SIGNS, ">signs.html") || die "Error creating the signs html file!: $!\n\n";
print SIGNS '
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<!-- Include jquery -->
<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.2/jquery.min.js"></script>

<!-- Include jquery mark ( for highlighting text )-->
<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/mark.js/6.1.0/jquery.mark.min.js"></script>

<!-- Include Data Tables-->
<link rel="stylesheet" href="https://cdn.datatables.net/1.10.12/css/jquery.dataTables.min.css">
<!-- CSS -->
<script src="https://cdn.datatables.net/1.10.12/js/jquery.dataTables.min.js"></script>
<!-- JS -->
<!-- Some custom js -->
    <script type="text/javascript" class="init">//<![CDATA[

            $(document).ready(function() {

                // create a data table
                var table = $(\'#my-table\').DataTable({
                  paging: false
                });

                // Apply the search
                    table.columns().every( function () {
                            var that = this;

                            $( \'input\', this.footer() ).on( \'keyup change clear\', function () {
                                 if ( that.search() !== this.value ) {
                                        that
                                                .search( this.value )
                            .draw();

                                  }
                           } );
                    } );

                //CODE BELOW HIGHLIGHTS ONLY IN GLOBAL SEARCH
                // add custom listener to draw event on the table
                table.on("draw",function() {
                    // get the search keyword
                    var keyword = $(\'#my-table_filter > label:eq(0) > input\').val();

                    // clear all the previous highlighting
                    $(\'#my-table\').unmark();

                    // highlight the searched word
                    $(\'#my-table\').mark(keyword,{});
                });

            });

        //]]>
    </script>
<STYLE>
  body {
    font-family: "Verdana";
    font-size: 10.5pt;
    line-height: 12pt;
    margin: 0;
  }
  mark {
            padding: 0px;
            background-color: rgb(255, 201, 14);
        }
  th, td {
      white-space: nowrap;
  }
</STYLE>
<title>WritEMe database - tokens</title>
</head>
<body>
';
print SIGNS '<p align=center><a href ="image_catalogue.html" target="middle">Image catalogue</a></p>'."\n";
print SIGNS '<table id="my-table" class="display" cellspacing="0" style="width:100%">'."\n";
print SIGNS "<thead><tr><th><\/th><\/tr><\/thead>\n\t<tbody>";

foreach my $sign (sort keys %context_hash) {
  next if ($sign eq ',');
  next if ($sign eq ';');
  next if ($sign =~m /\.\.\./);
  next if ($sign =~m /^Q\d+/);
  next if ($sign =~m /^n$/i);
  next if ($sign eq 'X');
  my $url = $sign.'_dataPage.html';
  $url =~ s/\|//g;
  $url = $datapath.$url;
  print SIGNS "\t<tr><td>".'<a href = "'.$url.'" target="middle">'.$sign.'</a></td></tr>'."\n";
}


print SIGNS "\t<\/tbody>\n".' 
</table>
</body>
</html>';
close SIGNS;

chdir $path.'\\'.$datapath or die "Impossible to navigate back to $path\\$datapath: $!\nProgram terminated prematurely\n";

#dataPage -- main panel
foreach my $sign (sort keys %geo_hash) {
  $sign =~s/^\s+|\s+$//;
  next if (!$sign);
  next if ($sign eq ',');
  next if ($sign eq ';');
  next if ($sign =~m /\.\.\./);
  next if ($sign =~m /^Q\d+/);
  next if ($sign =~m /^n$/i);
  next if ($sign eq 'X');
  my $filename = $sign.'_dataPage.html';
  $filename =~ s/\|//g;
  $filename =~ s/\<//g;
  $filename =~ s/\>//g;
  
  
  open(DATAPAGE, ">$filename") || die "Error creating the dataPage file for sign $sign!: $!\n\n";
  print DATAPAGE '
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8"/>
    <STYLE>
    body {
      font-family: "Times New Roman";
      font-size: 10.5pt;
      line-height: 12pt;
      margin: 0;
    }
    h1 {
      text-align: center;
      font-size:150%;
    }
    .tbl {
        border:1px solid;
    }
    .tbl tr td {
      border: 1px solid;
    }
    .tbl tr:nth-child(2n+1) {   background-color: #ffffff; }
    .tbl tr:nth-child(2n+0) {   background-color: #f9f7ec; }
    .plain_tbl {
        border: none;
        background-color:#ffffff;
    }
    .plain_tbl tr td {
      border: none;
      background-color:#ffffff;
      vertical-align: middle;
    }
    div {
      	margin-right: 10px;
    }
    img {
      width: 125px;
      height: auto;
    }

    body {
      font-family: Verdana;
      margin: 0;
    }

    p {
      word-wrap: break-word;
    }
    
    /* Style the tab */
    .tab {
      overflow: hidden;
      border: 1px solid #ccc;
      background-color: #f1f1f1;
    }
    
    /* Style the buttons inside the tab */
    .tab button {
      background-color: inherit;
      float: left;
      border: none;
      outline: none;
      cursor: pointer;
      padding: 14px 16px;
      transition: 0.3s;
      font-size: 17px;
    }
    
    /* Change background color of buttons on hover */
    .tab button:hover {
      background-color: #ddd;
    }
    
    /* Create an active/current tablink class */
    .tab button.active {
      background-color: #ccc;
    }
    
    /* Style the tab content */
    .tabcontent {
      display: none;
      padding: 6px 12px;
      border: 1px solid #ccc;
      border-top: none;
    }
    
    .wrapper {
      display: grid;
      grid-template-columns: repeat(7, 1fr);
      grid-column-gap: 10px;
      grid-row-gap: 10px;
    }

    .wrapper > div img {
      max-width: 100%;
    }

    </STYLE>
    <title>WritEMe palaeography database -'."$sign".'_dataPAGE</title>
    </head>
    <body>';
    
    
  print DATAPAGE '
  <div class="tab">
    <button class="tablinks" onclick="openCity(event, \'Sign_data\')" id="defaultOpen">Sign data</button>
    <button class="tablinks" onclick="openCity(event, \'Translit_data\')">Transliteration data</button>
    <button class="tablinks" onclick="openCity(event, \'Variations\')">Variations</button>
    <button class="tablinks" onclick="openCity(event, \'Cluster_data1\')">Cluster_data (1)</button>
    <button class="tablinks" onclick="openCity(event, \'Cluster_data2\')">Cluster_data (2)</button>
    
  </div>'."\n";
  
  ############### Sign data ###########################
   print DATAPAGE '
    <div id="Sign_data" class="tabcontent">
      <div>
      <h1>'."$sign".'</h1>
      </div>
      <div>
        <p><b>Frequency data</b>:
        <table>'."\n";
  foreach my $x (sort {$a <=> $b} keys %{$final_freq_hash{$sign}}) {
    my $datum = $final_freq_hash{$sign}{$x};
    my @parts = split ':', $datum;
    print DATAPAGE "\t\t\t<tr><td style=\"width:20%\">$parts[0]:</td><td style=\"width:80%\">$parts[1]</td></tr>\n";

  }
  print DATAPAGE "\t\t<\/table>\n";
  print DATAPAGE "\t\t<\/p><\/div><br>\n";
  if (exists $graphemic_hash{$sign}) {
    print DATAPAGE "\t<div><b>Related graphemes</b>:\n<p>";
    my @related_signs = sort keys %{$graphemic_hash{$sign}};
    for (my $i=0;$i<=$#related_signs;$i++) {
      if ((exists $geo_hash{$sign}) && ($related_signs[$i] !~ m/~x/)) {
        my $url = $related_signs[$i];
        $url =~s/\|//g;
        $url = $url.'_dataPage.html';
        $url = $datapath.$url;
        print DATAPAGE "<a href=\"$url\" target=\"middle\">$related_signs[$i]<\/a>";
        print DATAPAGE ',' if ($i<$#related_signs);
      } else {
        $graphemic_oddities{$sign}{$related_signs[$i]}++;
      }  
    }    
    #print DATAPAGE join ', ', @related_signs;
    print DATAPAGE "\t</p></div><br>\n";
  }
   
  
  print DATAPAGE "\n";
  if (exists $hash_img2{$sign}) {
    print DATAPAGE "<p><b>Variations</b>:<br>\n";
    print DATAPAGE "<div class=\"wrapper\">\n";
  
    foreach my $file (sort keys %{$hash_img2{$sign}}) {
        print DATAPAGE "   <div><img src=\"..\\images\\$file\">\n";
        my @P_parts = split /_+/, $file;
        my $Pnum = $P_parts[1];
        $Pnum =~s/~\d+//;
        my $obv_rev = $P_parts[2];
        $obv_rev =~ s/\.png$//;
        my @genre = keys %{$hash_data{$Pnum}{'Genre'}};
        #$hash_data{$CDLI_no}{$data_type}{$datum}++;
        print DATAPAGE "<br><small><a href=\"https:\/\/cdli.ucla.edu\/$Pnum\" target =\"_blank\">$Pnum<\/a> $obv_rev ($genre[0]) <\/small>\n";
        print DATAPAGE "   <\/div>\n";
    }
    print DATAPAGE "<\/div><\/p>\n";
  }
  
  
  
  print DATAPAGE "\t<\/div>\n"; 
   
   
   
  ############### trasliteration data ###########################
  #$final_translit_hash{$token}{$freq_tr}{$clean_tr} = @CDLI_refs;   
  print DATAPAGE '
      <div id="Translit_data" class="tabcontent">'."\n";
    #$final_freq_hash{$token}{$g_count} = datum
  print DATAPAGE "\t\t<table class=\"tbl\">\n";
  print DATAPAGE "\t\t\t<tr>\n\t\t\t\t<th>freq.<\/th>\n\t\t\t\t<th>transliteration<\/th>\n\t\t\t\t<th>reference<\/th>\n\t\t\t<\/tr>\n";
  foreach my $freq (sort {$b <=> $a} keys %{$final_translit_hash{$sign}}) {
    foreach my $tran (sort keys %{$final_translit_hash{$sign}{$freq}}) {
        print DATAPAGE "\t\t\t<tr>\n";
        print DATAPAGE "\t\t\t\t<td>".$freq.'</td>'."\n";
        print DATAPAGE "\t\t\t\t<td>".$tran.'</td>'."\n";
        print DATAPAGE "\t\t\t\t<td>\n";
        print DATAPAGE "\t\t\t\t\t<table border=0 class=\"plain_tbl\">\n";
        my @CDLI_refs = @{$final_translit_hash{$sign}{$freq}{$tran}};
        for (my $c=0;$c<=$#CDLI_refs;$c++) {
          my ($P_num) = $CDLI_refs[$c] =~ m/(P\d+)/;
          print DATAPAGE "\t\t\t\t\t\t<tr>\n";
          print DATAPAGE "\t\t\t\t\t\t\t<td>";
          my $src = "";
          if (exists $hash_img_files{$sign}{$CDLI_refs[$c]}) {
            $src = $hash_img_files{$sign}{$CDLI_refs[$c]};
            #print "FOUND IMAGE: $src\n";
            print DATAPAGE "<img src=\"..\\images\\$src\">";
            
          } else {
            print DATAPAGE "[---NO IMAGE---]";
          }
          print DATAPAGE "\n\t\t\t\t\t\t\t</td>";
          print DATAPAGE "\n\t\t\t\t\t\t\t<td>";
          if (($src) && ($src =~ m/'/)) {
                print DATAPAGE " (unc.) ";
          }  
          my @genre = keys %{$hash_data{$P_num}{'Genre'}};
          print DATAPAGE substr($genre[0], 0, 3).".: <a href=\"https:\/\/cdli.ucla.edu\/$P_num\" target =\"_blank\">".$CDLI_refs[$c]."<\/a><\/td>\n";     
          print DATAPAGE "\t\t\t\t\t\t<\/tr>";
        }
        print DATAPAGE "\t\t\t\t\t<\/table>\n";
        print DATAPAGE "\t\t\t\t<\/td>\n";
        print DATAPAGE "\t\t\t<\/tr>\n";
    }
  }
  print DATAPAGE "\t\t<\/table>\n";
  print DATAPAGE '</div>'."\n";    
  
  ############### Variations ###########################
  #$final_variations_hash{$token}{$ranking}{$cluster}{$CDLI_num}++;
   print DATAPAGE '
      <div id="Variations" class="tabcontent">'."\n";
  print DATAPAGE "\t\t<table class=\"tbl\">\n";
  print DATAPAGE "\t\t\t<tr>\n\t\t\t\t<th>rank<\/th>\n\t\t\t\t<th>variations<\/th>\n\t\t\t\t<th>reference<\/th>\n\t\t\t<\/tr>\n";
  if (!keys %{$final_variations_hash{$sign}}) {
    print DATAPAGE "\t\t\t<tr>\n\t\t\t\t<td>-<\/td>\n\t\t\t\t<td>[NO VARIATIONS]<\/td>\n\t\t\t\t<td>-<\/td>\n\t\t\t<\/tr>\n";
  }
  foreach my $freq (sort {$b <=> $a} keys %{$final_variations_hash{$sign}}) {
    foreach my $tran (sort keys %{$final_variations_hash{$sign}{$freq}}) {
        print DATAPAGE "\t\t\t<tr>\n";
        print DATAPAGE "\t\t\t\t<td>".$freq.'</td>'."\n";
        print DATAPAGE "\t\t\t\t<td>".$tran.'</td>'."\n";
        print DATAPAGE "\t\t\t\t<td>\n";
        print DATAPAGE "\t\t\t\t\t<table border=0 class=\"plain_tbl\">\n";
        my @CDLI_refs = keys %{$final_variations_hash{$sign}{$freq}{$tran}};
        for (my $c=0;$c<=$#CDLI_refs;$c++) {
          my ($P_num) = $CDLI_refs[$c] =~ m/(P\d+)/;
          print DATAPAGE "\t\t\t\t\t\t<tr>\n";
          print DATAPAGE "\t\t\t\t\t\t\t<td>";
          my $src = "";   
          
          
          
          print DATAPAGE "\n\t\t\t\t\t\t\t</td>";
          print DATAPAGE "\n\t\t\t\t\t\t\t<td>";
          if (($src) && ($src =~ m/'/)) {
                print DATAPAGE " (unc.) ";
          }  
          my @genre = keys %{$hash_data{$P_num}{'Genre'}};
          print DATAPAGE substr($genre[0], 0, 3).".: <a href=\"https:\/\/cdli.ucla.edu\/$P_num\" target =\"_blank\">".$CDLI_refs[$c]."<\/a><\/td>\n";     
          print DATAPAGE "\t\t\t\t\t\t<\/tr>";
        }
        print DATAPAGE "\t\t\t\t\t<\/table>\n";
        print DATAPAGE "\t\t\t\t<\/td>\n";
        print DATAPAGE "\t\t\t<\/tr>\n";
    }
  }
  print DATAPAGE "\t\t<\/table>\n";
  
  print DATAPAGE '</div>'."\n";    
  
  
  
  ############### cluster data (1) ########################### 
 
  #$final_cluster1_hash{$token}{$countx}{$linex} = [ @CDLI_refs ];
  #$final_translit_hash{$token}{$freq_tr}{$clean_tr} = @CDLI_refs;   
  print DATAPAGE '
      <div id="Cluster_data1" class="tabcontent">'."\n";
    #$final_freq_hash{$token}{$g_count} = datum
  print DATAPAGE "\t\t<table class=\"tbl\">\n";
  print DATAPAGE "\t\t\t<tr>\n\t\t\t\t<th>freq.<\/th>\n\t\t\t\t<th>cluster<\/th>\n\t\t\t\t<th>reference<\/th>\n\t\t\t<\/tr>\n";
  foreach my $freq (sort {$b <=> $a} keys %{$final_cluster1_hash{$sign}}) {
    foreach my $tran (sort keys %{$final_cluster1_hash{$sign}{$freq}}) {
        print DATAPAGE "\t\t\t<tr>\n";
        print DATAPAGE "\t\t\t\t<td>".$freq.'</td>'."\n";
        print DATAPAGE "\t\t\t\t<td>".$tran.'</td>'."\n";
        print DATAPAGE "\t\t\t\t<td>\n";
        print DATAPAGE "\t\t\t\t\t<table border=0 class=\"plain_tbl\">\n";
        my @CDLI_refs = @{$final_cluster1_hash{$sign}{$freq}{$tran}};
        for (my $c=0;$c<=$#CDLI_refs;$c++) {
          my ($P_num) = $CDLI_refs[$c] =~ m/(P\d+)/;
          print DATAPAGE "\t\t\t\t\t\t<tr>\n";
          print DATAPAGE "\t\t\t\t\t\t\t<td>";
          my $src = "";
          if (exists $hash_img_files{$sign}{$CDLI_refs[$c]}) {
            $src = $hash_img_files{$sign}{$CDLI_refs[$c]};
            #print "FOUND IMAGE: $src\n";
            print DATAPAGE "<img src=\"..\\images\\$src\">";
            
          } else {
            print DATAPAGE "[---NO IMAGE---]";
          }
          print DATAPAGE "\n\t\t\t\t\t\t\t</td>";
          print DATAPAGE "\n\t\t\t\t\t\t\t<td>";
          if (($src) && ($src =~ m/'/)) {
                print DATAPAGE " (unc.) ";
          }  
          my @genre = keys %{$hash_data{$P_num}{'Genre'}};
          print DATAPAGE substr($genre[0], 0, 3).".: <a href=\"https:\/\/cdli.ucla.edu\/$P_num\" target =\"_blank\">".$CDLI_refs[$c]."<\/a><\/td>\n";     
          print DATAPAGE "\t\t\t\t\t\t<\/tr>";
        }
        print DATAPAGE "\t\t\t\t\t<\/table>\n";
        print DATAPAGE "\t\t\t\t<\/td>\n";
        print DATAPAGE "\t\t\t<\/tr>\n";
    }
  }
  print DATAPAGE "\t\t<\/table>\n";
  print DATAPAGE '</div>'."\n";    
  
  
  
  ############### cluster data (2) ########################### 
 
  #$final_cluster1_hash{$token}{$countx}{$linex} = [ @CDLI_refs ];
  #$final_translit_hash{$token}{$freq_tr}{$clean_tr} = @CDLI_refs;   
  print DATAPAGE '
      <div id="Cluster_data2" class="tabcontent">'."\n";
    #$final_freq_hash{$token}{$g_count} = datum
  print DATAPAGE "\t\t<table class=\"tbl\">\n";
  print DATAPAGE "\t\t\t<tr>\n\t\t\t\t<th>freq.<\/th>\n\t\t\t\t<th>cluster<\/th>\n\t\t\t\t<th>reference<\/th>\n\t\t\t<\/tr>\n";
  foreach my $freq (sort {$b <=> $a} keys %{$final_cluster2_hash{$sign}}) {
    foreach my $tran (sort keys %{$final_cluster2_hash{$sign}{$freq}}) {
        print DATAPAGE "\t\t\t<tr>\n";
        print DATAPAGE "\t\t\t\t<td>".$freq.'</td>'."\n";
        print DATAPAGE "\t\t\t\t<td>".$tran.'</td>'."\n";
        print DATAPAGE "\t\t\t\t<td>\n";
        print DATAPAGE "\t\t\t\t\t<table border=0 class=\"plain_tbl\">\n";
        my @CDLI_refs = @{$final_cluster2_hash{$sign}{$freq}{$tran}};
        for (my $c=0;$c<=$#CDLI_refs;$c++) {
          my ($P_num) = $CDLI_refs[$c] =~ m/(P\d+)/;
          print DATAPAGE "\t\t\t\t\t\t<tr>\n";
          print DATAPAGE "\t\t\t\t\t\t\t<td>";
          my $src = "";
          if (exists $hash_img_files{$sign}{$CDLI_refs[$c]}) {
            $src = $hash_img_files{$sign}{$CDLI_refs[$c]};
            #print "FOUND IMAGE: $src\n";
            print DATAPAGE "<img src=\"..\\images\\$src\">";
            
          } else {
            print DATAPAGE "[---NO IMAGE---]";
          }
          print DATAPAGE "\n\t\t\t\t\t\t\t</td>";
          print DATAPAGE "\n\t\t\t\t\t\t\t<td>";
          if (($src) && ($src =~ m/'/)) {
                print DATAPAGE " (unc.) ";
          }  
          my @genre = keys %{$hash_data{$P_num}{'Genre'}};
          print DATAPAGE substr($genre[0], 0, 3).".: <a href=\"https:\/\/cdli.ucla.edu\/$P_num\" target =\"_blank\">".$CDLI_refs[$c]."<\/a><\/td>\n";     
          print DATAPAGE "\t\t\t\t\t\t<\/tr>";
        }
        print DATAPAGE "\t\t\t\t\t<\/table>\n";
        print DATAPAGE "\t\t\t\t<\/td>\n";
        print DATAPAGE "\t\t\t<\/tr>\n";
    }
  }
  print DATAPAGE "\t\t<\/table>\n";
  print DATAPAGE '</div>'."\n";    
  
  
    print DATAPAGE '
    <script>
    function openCity(evt, cityName) {
      var i, tabcontent, tablinks;
      tabcontent = document.getElementsByClassName("tabcontent");
      for (i = 0; i < tabcontent.length; i++) {
        tabcontent[i].style.display = "none";
      }
      tablinks = document.getElementsByClassName("tablinks");
      for (i = 0; i < tablinks.length; i++) {
        tablinks[i].className = tablinks[i].className.replace(" active", "");
      }
      document.getElementById(cityName).style.display = "block";
      evt.currentTarget.className += " active";
    }
    
    // Get the element with id="defaultOpen" and click on it
    document.getElementById("defaultOpen").click();
    </script>
    
    
    </body>
    </html>';
close DATAPAGE;
}

chdir $path or die "Can't navigate to $path: $!. Program terminated prematurely.\n";
##############STATISTICS

open(STATS, ">statistics.html") || die "Error creating the statistics file!: $!\n\n";
print STATS '<!DOCTYPE html>
<html lang="en">
  <meta http-equiv="content-type" content="text/html; charset=UTF-8">
  <meta charset="utf-8">
  <!-- Include jquery -->
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.2/jquery.min.js"></script>

  <!-- Include jquery mark ( for highlighting text )-->
  <script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/mark.js/6.1.0/jquery.mark.min.js"></script>

  <!-- Include Data Tables-->
  <link rel="stylesheet" href="https://cdn.datatables.net/1.10.12/css/jquery.dataTables.min.css">
  <!-- CSS -->
  <script src="https://cdn.datatables.net/1.10.12/js/jquery.dataTables.min.js"></script>
  <!-- JS -->

  <script src="https://cdn.jsdelivr.net/npm/chart.js@2.8.0"></script>

  <style>
    html,
    body {
      width: 100%;
      height: 100%;
    }

    body {
      font-family: Verdana;
      font-size: 10.5pt;
      line-height: 12pt;
      margin: 0;
    }

    .float-left-child {
      float: left
    }


    .inline-block-child {
      display: inline-block;
    }


    .flex-parent {
      display: flex;
    }

    .flex-child {
      flex: 1;
    }


    .inline-flex-parent {
      display: inline-flex;
    }


    /* base css */
    body {
      padding: 3rem;
    }

    h3 {
      margin: 1.5rem 0 .25em;
      clear: both;
    }

    .parent {
      padding: 1rem
    }

    .child {
      padding: 1rem
    }
    
    td {
      white-space: nowrap;
    }
    
    .grid-parent {
      display: grid;
      grid-template-columns: 1fr 1fr
    }

    .columns {
      column-count: 10;
    }

    .text_ID {
      font-size: 12pt;
      color: blue;
    }

    .score {
      font-size: 12pt;
      color: black;
      font-weight: bold;
    }

    .cat_info {
      font-size: 12pt;
      color: gray;
    }

    mark {
      padding: 0px;
      background-color: rgb(255, 201, 14);
    }

    .text-wrap {
      white-space: normal;
    }

    .width-200 {
      width: 200px;
    }
  </style>
  <title>WritEMe database -- STATISTICS</title>
  <style type="text/css">
    /* Chart.js */
    @keyframes chartjs-render-animation {
      from {
        opacity: .99
      }

      to {
        opacity: 1
      }
    }

    .chartjs-render-monitor {
      animation: chartjs-render-animation 1ms
    }

    .chartjs-size-monitor,
    .chartjs-size-monitor-expand,
    .chartjs-size-monitor-shrink {
      position: absolute;
      direction: ltr;
      left: 0;
      top: 0;
      right: 0;
      bottom: 0;
      overflow: hidden;
      pointer-events: none;
      visibility: hidden;
      z-index: -1
    }

    .chartjs-size-monitor-expand>div {
      position: absolute;
      width: 1000000px;
      height: 1000000px;
      left: 0;
      top: 0
    }

    .chartjs-size-monitor-shrink>div {
      position: absolute;
      width: 200%;
      height: 200%;
      left: 0;
      top: 0
    }
  </style>
</head>
<body>
';

my $total_texts_without_transliteration = scalar keys %texts_without_transliteration;
my $total_texts_without_linguistic_content = scalar keys %texts_without_linguistic_content;
my $total_texts_with_transliteration = $statistics{'total_texts_with_transliteration'};
my $total_lines = $statistics{'total_lines'};
my $total_tokens = $statistics{'total_tokens'};
print STATS "<p style=\"padding:0 15px 0 15px;\"><b>Total input texts</b>:".commify($total_input_texts)."<\/p>\n";
print STATS "<p style=\"padding:0 15px 0 15px;\"><b>Total texts without transliteration</b>:".commify($total_texts_without_transliteration)."<\/p>\n";
print STATS "<p style=\"padding:0 15px 0 15px;\"><b>Total texts without linguistic content</b>:".commify($total_texts_without_linguistic_content)."<\/p>\n";
print STATS "<p style=\"padding:0 15px 0 15px;\"><b>Total texts with linguistic content</b>:".commify($total_texts_with_transliteration)."<\/p>\n";
print STATS "<p style=\"padding:0 15px 0 15px;\"><b>Total lines</b>:".commify($total_lines)."<\/p>\n";
print STATS "<p style=\"padding:0 15px 0 15px;\"><b>Total tokens</b>:".commify($total_tokens)."<\/p>\n";

print STATS '<div class=\'parent inline-flex-parent\'>
  <div class=\'child\'>
    <table>'."\n";
print STATS '<tr><th>Provenance</th><th>#</th>'."\n";
foreach my $prov (sort {$statistics{'provenance'}{$b} <=> $statistics{'provenance'}{$a} } keys %{$statistics{'provenance'}}) {
  my $prov_for_printing = $prov;
  $prov_for_printing =~ s/\(.+?\)//;          
  print STATS "<tr><td style=\"padding:0 15px 0 15px;\">$prov_for_printing<\/td><td>".commify($statistics{'provenance'}{$prov})."x<\/td><\/tr>\n";  
}
print STATS "</table>\n";
print STATS '</div>
<div class=\'child inline-block-child\'>
  <div id="container" style="width: 100%;">
    <div class="chartjs-size-monitor">
      <div class="chartjs-size-monitor-expand">
        <div class=""></div>
      </div>
      <div class="chartjs-size-monitor-shrink">
        <div class=""></div>
      </div>
    </div>
    <canvas id="myChart" style="display: block; width: 900px; height: 600px;" class="chartjs-render-monitor" width="900" height="600"></canvas>
  </div>

  <script>
    var ctx = document.getElementById(\'myChart\').getContext(\'2d\');
    var gradientStroke = ctx.createLinearGradient(500, 0, 100, 0);
    gradientStroke.addColorStop(0, \'#80b6f4\');
    gradientStroke.addColorStop(1, \'#f49080\');

    var myChart = new Chart(ctx, {
      type: \'bar\',
      data: {
        labels: [';
my @prov_labels = sort {$statistics{'provenance'}{$b} <=> $statistics{'provenance'}{$a} } keys %{$statistics{'provenance'}};
my @lab_for_printing = @prov_labels;
foreach my $lab (@lab_for_printing) {
  $lab =~ s/\(.+?\)//;
  $lab = '\''.$lab.'\'';                       
}    
print STATS join ', ', @lab_for_printing;
print STATS '],
    datasets: [{
          label: \'\',
          backgroundColor: gradientStroke,
          borderColor: gradientStroke,
          pointBorderColor: gradientStroke,
          pointBackgroundColor: gradientStroke,
          pointHoverBackgroundColor: gradientStroke,
          pointHoverBorderColor: gradientStroke,
          pointBorderWidth: 10,
          pointHoverRadius: 10,
          pointHoverBorderWidth: 1,
          pointRadius: 3,
          fill: false,
          borderWidth: 14,
          data: [';
for (my $i=0;$i<=$#prov_labels;$i++) {
  print STATS $statistics{'provenance'}{$prov_labels[$i]};
  if ($i<$#prov_labels) {
    print STATS ", ";
  }
}
   print STATS '],
      }]
      },
      options: {
        legend: {
          display: false
        },
        tooltips: {
          callbacks: {
            label: function(tooltipItem) {
              return tooltipItem.yLabel;
            }
          }
        },
        scales: {
          xAxes: [{
            ticks: {
              beginAtZero: true
            },
            scaleLabel: {
              display: true,
              labelString: \'Provenance\'
            }
          }],
          yAxes: [{
            ticks: {
              beginAtZero: true,
              callback: function(value) {
                if (value % 1 === 0) {
                  return value;
                }
              }
            },
            scaleLabel: {
              display: true,
              labelString: \'# of texts\'
            }
          }]
        }
      }
    });
  </script>
  </div>
</div>';



### genre 
print STATS '<div class=\'parent inline-flex-parent\'>
  <div class=\'child\'>
    <table>'."\n";
print STATS '<tr><th>Genre</th><th>#</th>'."\n";
foreach my $gen (sort {$statistics{'genre'}{$b} <=> $statistics{'genre'}{$a}} keys %{$statistics{'genre'}}) {
   print STATS "<tr><td style=\"padding:0 15px 0 15px;\">$gen<\/td><td>".commify($statistics{'genre'}{$gen})."x<\/td><\/tr>\n";
}
print STATS "</table>\n";
print STATS '</div>
<div class=\'child inline-block-child\'>
  <div id="container" style="width: 100%;">
    <div class="chartjs-size-monitor">
      <div class="chartjs-size-monitor-expand">
        <div class=""></div>
      </div>
      <div class="chartjs-size-monitor-shrink">
        <div class=""></div>
      </div>
    </div>
    <canvas id="myChart2" style="display: block; width: 900px; height: 600px;" class="chartjs-render-monitor" width="900" height="600"></canvas>
  </div>

  <script>
    var ctx = document.getElementById(\'myChart2\').getContext(\'2d\');
    var gradientStroke = ctx.createLinearGradient(500, 0, 100, 0);
    gradientStroke.addColorStop(0, \'#80b6f4\');
    gradientStroke.addColorStop(1, \'#f49080\');

    var myChart = new Chart(ctx, {
      type: \'bar\',
      data: {
        labels: [';
my @prov_labels2 = sort {$statistics{'genre'}{$b} <=> $statistics{'genre'}{$a} } keys %{$statistics{'genre'}};
my @lab_for_printing2 = @prov_labels2;
foreach my $lab (@lab_for_printing2) {
  $lab =~ s/\(.+?\)//;
  $lab = '\''.$lab.'\'';                       
}    
print STATS join ', ', @lab_for_printing2;
print STATS '],
    datasets: [{
          label: \'\',
          backgroundColor: gradientStroke,
          borderColor: gradientStroke,
          pointBorderColor: gradientStroke,
          pointBackgroundColor: gradientStroke,
          pointHoverBackgroundColor: gradientStroke,
          pointHoverBorderColor: gradientStroke,
          pointBorderWidth: 10,
          pointHoverRadius: 10,
          pointHoverBorderWidth: 1,
          pointRadius: 3,
          fill: false,
          borderWidth: 14,
          data: [';
for (my $i=0;$i<=$#prov_labels2;$i++) {
  print STATS $statistics{'genre'}{$prov_labels2[$i]};
  if ($i<$#prov_labels2) {
    print STATS ", ";
  }
}
   print STATS '],
      }]
      },
      options: {
        legend: {
          display: false
        },
        tooltips: {
          callbacks: {
            label: function(tooltipItem) {
              return tooltipItem.yLabel;
            }
          }
        },
        scales: {
          xAxes: [{
            ticks: {
              beginAtZero: true
            },
            scaleLabel: {
              display: true,
              labelString: \'Genre\'
            }
          }],
          yAxes: [{
            ticks: {
              beginAtZero: true,
              callback: function(value) {
                if (value % 1 === 0) {
                  return value;
                }
              }
            },
            scaleLabel: {
              display: true,
              labelString: \'# of texts\'
            }
          }]
        }
      }
    });
  </script>
  </div>
</div>';





#period
print STATS '<div class=\'parent inline-flex-parent\'>
  <div class=\'child\'>
    <table>'."\n";
print STATS '<tr><th>Period</th><th>#</th>'."\n";
foreach my $per (sort { $statistics{'period'}{$b} <=> $statistics{'period'}{$a} } keys %{$statistics{'period'}}) {
  my $per_for_printing = $per;
  $per_for_printing =~ s/\(.+?\)//g;
  $per_for_printing =~ s/  / /g;
  $per_for_printing =~ s/Early Dynastic/ED/g;
  print STATS "<tr><td style=\"padding:0 15px 0 15px;\">$per_for_printing<\/td><td>".commify($statistics{'period'}{$per})."x<\/td><\/tr>\n";  
}
print STATS "</table>\n";
print STATS '</div>
<div class=\'child inline-block-child\'>
  <div id="container" style="width: 100%;">
    <div class="chartjs-size-monitor">
      <div class="chartjs-size-monitor-expand">
        <div class=""></div>
      </div>
      <div class="chartjs-size-monitor-shrink">
        <div class=""></div>
      </div>
    </div>
    <canvas id="myChart3" style="display: block; width: 900px; height: 600px;" class="chartjs-render-monitor" width="900" height="600"></canvas>
  </div>

  <script>
    var ctx = document.getElementById(\'myChart3\').getContext(\'2d\');
    var gradientStroke = ctx.createLinearGradient(500, 0, 100, 0);
    gradientStroke.addColorStop(0, \'#80b6f4\');
    gradientStroke.addColorStop(1, \'#f49080\');

    var myChart = new Chart(ctx, {
      type: \'bar\',
      data: {
        labels: [';
my @prov_labels3 = sort {$statistics{'period'}{$b} <=> $statistics{'period'}{$a} } keys %{$statistics{'period'}};
my @lab_for_printing3 = @prov_labels3;
foreach my $lab (@lab_for_printing3) {
  $lab =~ s/\(.+?\)//g;
  $lab =~ s/\(.+?\)//g;
  $lab =~ s/  / /g;
  $lab =~ s/Early Dynastic/ED/g;
  $lab = '\''.$lab.'\'';                       
}    
print STATS join ', ', @lab_for_printing3;
print STATS '],
    datasets: [{
          label: \'\',
          backgroundColor: gradientStroke,
          borderColor: gradientStroke,
          pointBorderColor: gradientStroke,
          pointBackgroundColor: gradientStroke,
          pointHoverBackgroundColor: gradientStroke,
          pointHoverBorderColor: gradientStroke,
          pointBorderWidth: 10,
          pointHoverRadius: 10,
          pointHoverBorderWidth: 1,
          pointRadius: 3,
          fill: false,
          borderWidth: 14,
          data: [';
for (my $i=0;$i<=$#prov_labels3;$i++) {
  my  $lab_for_p = $statistics{'period'}{$prov_labels3[$i]};
  print STATS $lab_for_p;
  if ($i<$#prov_labels3) {
    print STATS ", ";
  }
}
   print STATS '],
      }]
      },
      options: {
        legend: {
          display: false
        },
        tooltips: {
          callbacks: {
            label: function(tooltipItem) {
              return tooltipItem.yLabel;
            }
          }
        },
        scales: {
          xAxes: [{
            ticks: {
              beginAtZero: true
            },
            scaleLabel: {
              display: true,
              labelString: \'Period\'
            }
          }],
          yAxes: [{
            ticks: {
              beginAtZero: true,
              callback: function(value) {
                if (value % 1 === 0) {
                  return value;
                }
              }
            },
            scaleLabel: {
              display: true,
              labelString: \'# of texts\'
            }
          }]
        }
      }
    });
  </script>
  </div>
</div>';







print STATS "<p><b>Texts processed</b>:<br>\n";
print STATS '<div class ="columns">';
foreach my $CDLI_num (sort keys %{$statistics{'texts'}}) {
  print STATS "$CDLI_num<br>\n";
}
print STATS "</div>\n</p>\n";
print STATS '</body>'."\n".'</html>';
close STATS;

chdir $path.'\\' or die "Impossible to navigate back to $path\\$datapath: $!\nProgram terminated prematurely\n";

#SIGN CATALOGUE
open(IMAGE_CATALOGUE, ">image_catalogue.html") || die "Error creating the image catalogue html file!: $!\n\n";
print IMAGE_CATALOGUE '
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <title>WritEMe database - default</title>
    <STYLE>
      html,body{
        width: 100%;
        height: 100%;
      }
      body {
        font-family: Verdana, sans-serif;
        font-size: 10.5pt;
        line-height: 12pt;
        word-wrap: normal;
        margin: 0;
      }
      img {
      width: 125px;
      height: auto;
    }
    </STYLE>
  </head>
  <body>
    <table>'."\n";


foreach my $sign_name_file (sort keys %hash_img2) {
  print IMAGE_CATALOGUE "\t\t<tr>\n\t\t\t<td>$sign_name_file<\/td>\n";
  foreach my $file (sort keys %{$hash_img2{$sign_name_file}}) {
      print IMAGE_CATALOGUE "\t\t\t<td><img src=\"images\\$file\"><\/td>\n";
  }
  print IMAGE_CATALOGUE "\t\t</tr>\n";
}
print IMAGE_CATALOGUE '  </table>
</body>
</html>
';
close IMAGE_CATALOGUE;


chdir $path or die "Impossible to navigate to $path. Program terminated prematurely.\n";

#Download
open(DOWNLOAD, ">download.html") || die "Error creating the db_default html file!: $!\n\n";
print DOWNLOAD '
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <title>WritEMe database - default</title>
    <STYLE>
      html,body{
        width: 100%;
        height: 100%;
      }
      body {
        font-family: Verdana, sans-serif;
        font-size: 10.5pt;
        line-height: 12pt;
        word-wrap: normal;
        padding: 2em;
      }
    </STYLE>
  </head>
  <body>
    <p>This page provides database data in <a href="https://www.json.org/" target="_blank">JSON</a> format, in order to maximize interoperability and data exploitation.</p>
    <ul>
      <li><a href="'.$jsonpath.'WritEMe_graphemic_db_transliteration_data.json" target="_blank">transliteration data</a></li>
      <li><a href="'.$jsonpath.'WritEMe_graphemic_db_variation_data.json.json" target="_blank">variation data</a></li>
      <li><a href="'.$jsonpath.'WritEMe_graphemic_db_cluster1_data.json.json" target="_blank">cluster data (1)</a></li>
      <li><a href="'.$jsonpath.'WritEMe_graphemic_db_cluster2_data.json.json" target="_blank">cluster data (2)</a></li>
    </ul>
  </body>
</html>
';
close DOWNLOAD;

#Json
print "... working on JSON files ...\n";
chdir $path.'\\'.$jsonpath or die "Can't navigate to json folder, program terminated prematurely: $!";

#$final_variations_hash{$token}{$final_rank}{$cluster}{$CDLI_num}++;
my $json = JSON::MaybeXS->new(utf8 => 1, pretty => 1, sort_by => 1);
open(JSON1, ">WritEMe_graphemic_db_transliteration_data.json") || die "Error creating the json output file!: $!\n\n";
print JSON1 $json->encode(\%geo_hash);
close JSON1;

open(JSON2, ">WritEMe_graphemic_db_cluster1_data.json") || die "Error creating the json output file!: $!\n\n";
print JSON2 $json->encode(\%final_cluster1_hash);
close JSON2;

open(JSON3, ">WritEMe_graphemic_db_cluster2_data.json") || die "Error creating the json output file!: $!\n\n";
print JSON3 $json->encode(\%final_cluster2_hash);
close JSON3;

open(JSON4, ">WritEMe_graphemic_db_variation_data.json") || die "Error creating the json output file!: $!\n\n";

foreach my $sign (keys %geo_hash) {
  if (!exists $final_variations_hash{$sign}) {
    $final_variations_hash{$sign}{'[NO_RANK]'}{'[NO_VARIATIONS]'}{'[NO_REFERENCE]'}++;
  }
}
print JSON4 $json->encode(\%final_variations_hash);
close JSON4;



print "Done!\n";
close OUT;

close WARNINGS;

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

foreach my $sign (sort keys %graphemic_oddities) {
  print "$sign\n";
  foreach my $odd (sort keys %{$graphemic_oddities{$sign}}){
    print "\t$odd\n";
  }
}