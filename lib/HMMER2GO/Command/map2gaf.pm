package HMMER2GO::Command::map2gaf;
# ABSTRACT: Generate association file for gene and GO term mappings.

use 5.012;
use strict; 
use warnings;
use HMMER2GO -command;
use IPC::System::Simple qw(system);
use LWP::UserAgent;
use File::Basename;

sub opt_spec {
    return (    
        [ "infile|i=s",  "Tab-delimited file containing gene -> GO term mappings (GO terms should be separated by commas)." ],
        [ "outfile|o=s", "File name for the association file."                                   ],
        [ "species|s=s", "The species name to be used in the association file."                  ],
	[ "gofile|g=s",  "GO.terms_alt_ids file containing the one letter code for each term."   ],
    );
}

sub validate_args {
    my ($self, $opt, $args) = @_;

    my $command = __FILE__;
    if ($self->app->global_options->{man}) {
	system([0..5], "perldoc $command");
    }
    else {
	$self->usage_error("Too few arguments.") 
	    unless $opt->{infile} && $opt->{outfile} && $opt->{species};
    }
} 

sub execute {
    my ($self, $opt, $args) = @_;

    exit(0) if $self->app->global_options->{man};
    my $infile  = $opt->{infile};
    my $outfile = $opt->{outfile};
    my $species = $opt->{species};
    my $gofile  = $opt->{gofile};

    my $result = _generate_go_association($infile, $outfile, $species, $gofile);
}

sub _generate_go_association {
    my ($infile, $outfile, $species, $gofile) = @_;

    $gofile = _get_term_file() if !$gofile;

    open my $in, '<', $infile or die "\nERROR: Could not open file: $infile\n";
    open my $go, '<', $gofile or die "\nERROR: Could not open file: $gofile\n";
    open my $out, '>', $outfile or die "\nERROR: Could not open file: $outfile\n";

    ## NB: This approach was inspired by some Python code posted by 
    ##     Damian Kao on his blog: http://blog.nextgenetics.net. 
    ##     That is where the hardcoded fields below come from, which works fine with
    ##     Ontologizer, though we may want to make this an option for other
    ##     purposes.
    say $out "!gaf-version: 2.0";

    my %gohash;
    while (<$go>) {
	chomp;
	next if /^!/;
	my @go_data = split;
	next unless defined $go_data[0] && defined $go_data[-1];
	next if $go_data[-1] eq "obs";
	$gohash{$go_data[0]} = $go_data[-1];
    }
    close $go;

    while (<$in>) {
	chomp;
	my @go_mappings = split /\t/, $_;
	my $dbstring = "db.".$go_mappings[0];
	my @go_terms = split /\,/, $go_mappings[1];
	for my $term (@go_terms) {
	    if (exists $gohash{$term}) {
		    say $out join "\t", $species,$dbstring,$go_mappings[0],"0",$term,"PMID:0000000",
                    "ISO","0",$gohash{$term},"0","0","gene","taxon:79327","23022011","PFAM";
		}
	}
    }
    close $in;
    close $out;

    unlink $gofile;
}

sub _get_term_file {
    my $url      = 'ftp://ftp.geneontology.org/pub/go/doc';
    my $file     = 'GO.terms_alt_ids';
    my $endpoint = $url."/$file";
 
    my $ua = LWP::UserAgent->new;

    my $response = $ua->get($endpoint);

    unless ($response->is_success) {
        die "Can't get url $endpoint -- ", $response->status_line;
    }

    open my $out, '>', $file or die "\nERROR: Could not open file: $!\n";
    say $out $response->content;
    close $out;

    return $file;
}

1;
__END__

=pod

=head1 NAME 
                                                                       
 hmmer2go map2gaf - Create GO Annotation Format (GAF) file for statistical analysis

=head1 SYNOPSIS    

 hmmer2go map2gaf -i genes_orfs_GOterm_mapping.tsv -s 'Helianthus annuus' -o genes_orfs_GOterm_mapping.gaf

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 DESCRIPTION
                                                                   
 This command takes the sequence and GO term mappings generated by the 'hmmer2go mapterms'
 and creates an association file in GAF format.

=head1 REQUIRED ARGUMENTS

=over 2

=item -i, --infile

The sequence ID and GO term mapping file generated by the 'hmmer2go mapterms' command. The file
should be a two column tab-delimted file with the sequence ID in the first column and the GO terms
separated by commas in the second column.

=item -o, --outfile

The file GO Annotation Format (GAF) file to be created by this command. See http://www.geneontology.org/GO.format.gaf-2_0.shtml
for the specifications on this format.

=item -s, --species

A species name must be given when creating the association. This should be the epithet in quotes. An example is provided
in the synopsis section of the document.

=back

=head1 OPTIONS

=over 2

=item -g, --gofile

The GO.terms_alt_ids file obtained from the Gene Ontology website. If not provided, the latest version will be downloaed and
used.

=item -h, --help

Print a usage statement. 

=item -m, --man

Print the full documentation.

=back 

=cut 

