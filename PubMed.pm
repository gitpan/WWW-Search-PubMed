# PubMed.pm
# by Jim Smyser
# Copyright (C) 2000 by Jim Smyser 
# $Id: PubMed.pm,v 1.00 2000/06/18 17:49:25 jims Exp $


package WWW::Search::PubMed;

=head1 NAME

WWW::Search::PubMed - class for searching National Library of Medicine 

=head1 SYNOPSIS

use WWW::Search;

$query = "lung cancer treatment"; 
$search = new WWW::Search('PubMed');
$search->native_query(WWW::Search::escape_query($query));
$search->maximum_to_retrieve(100);
while (my $result = $search->next_result()) {

$url = $result->url;
$title = $result->title;
$desc = $result->description;

print <a href=$url>$title<br>$desc<p>\n"; 
} 

=head1 DESCRIPTION

WWW::Search class for searching National Library of Medicine
(PubMed). If you never heard of PubMed, Medline or don't know
the difference between a Abstract and Citation -- you then
can live without this backend.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 AUTHOR

C<WWW::Search::PubMed> is written and maintained by Jim Smyser
<jsmyser@bigfoot.com>.

=head1 COPYRIGHT

WWW::Search Copyright (c) 1996-1998 University of Southern California.
All rights reserved. PubMed.pm by Jim Smyser.                                           
                                                               
THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut
#'

#####################################################################
require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.0';

use Carp ();
use WWW::Search(qw(generic_option strip_tags));

require WWW::SearchResult;

sub native_setup_search {

        my($self, $native_query, $native_options_ref) = @_;
        $self->{_debug} = $native_options_ref->{'search_debug'};
        $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
        $self->{_debug} = 0 if (!defined($self->{_debug}));
        $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
        $max =  $self->maximum_to_retrieve;
        $self->user_agent('user');
        $self->{_next_to_retrieve} = 1;
        $self->{'_num_hits'} = 0;
             if (!defined($self->{_options})) {
             $self->{_options} = {
 'search_url' => 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=PubMed&orig_db=PubMed&term=' . $native_query . '&cmd=search&cmd_current=&WebEnv=&dispmax=10',
            };
             }
        my $options_ref = $self->{_options};
        if (defined($native_options_ref))
             {
        # Copy in new options.
        foreach (keys %$native_options_ref)
             {
        $options_ref->{$_} = $native_options_ref->{$_};
             } 
             } 
        # Process the options.
        my($options) = '';
        foreach (sort keys %$options_ref)
             {
        next if (generic_option($_));
        $options .= $_ . '=' . $options_ref->{$_} . '&';
             }
        chop $options;
        $self->{_next_url} = $self->{_options}{'search_url'};
             } 
# private
sub native_retrieve_some {

        my ($self) = @_;
        print STDERR "**PubMed Search Underway**\n" if $self->{_debug};
            
        # Fast exit if already done:
        return undef if (!defined($self->{_next_url}));
            
        # If this is not the first page of results, sleep so as to not
        # overload the server:
        $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
            
        # Get some if were not already scoring somewhere else:
        my($response) = $self->http_request('GET', $self->{_next_url});
        
        $self->{response} = $response;
        if (!$response->is_success)
             {
        return undef;
             }
        $self->{'_next_url'} = undef;
        print STDERR "**PubMed Response\n" if $self->{_debug};
        # parse the output
        my ($HEADER, $HITS, $DESC) = qw(HE HI DE);
        my $hits_found = 0;
        my $state = $HEADER;
        my $hit = ();
        foreach ($self->split_lines($response->content()))
             {
        next if m@^$@; # short circuit for blank lines
        if ($state eq $HEADER && m|>Page \d+ of ([\d,]+)</td>|i) 
        {
        $self->approximate_result_count($1);
        $state = $HITS;
        } 
   elsif ($state eq $HITS && m@^<td width="100%"><.*?><a href="(.*?)">(.+)</a>$@i) 
        {
        my ($url, $title) = ($1,$2);
        if (defined($hit))
            {
        push(@{$self->{cache}}, $hit);
            };
        $hit = new WWW::SearchResult;
        $hits_found++;
        $url =~ s/dopt=Abstract/dopt=Medline/g;
        $hit->add_url($url);
        $hit->title($title);
        $state = $DESC;
        } 
    elsif ($state eq $DESC && m|^<dd>(.+)<br></font>$|i) 
        {
        $desc = $1;
        $desc =~ s/<font size=\"-1\">//g;
        $hit->description($desc);
        $state = $HITS;
        };
        if (defined($hit)) {
            push(@{$self->{cache}}, $hit);
        };
        $self->{_next_url} = undef;
        };
        return $hits_found;
}
1;
