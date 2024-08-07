#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use JSON qw(decode_json);
use Encode qw(encode);
use Getopt::Std;

# Default values
my $DEFAULT_WIKI_ID = "";
my $DEFAULT_AUTH_HEADER_VALUE = ""; # "dooray-api xxxxxxxxxxxx:yyyyyyyyyyyyyyyyyyyyyy"

# Help message
my $help_message = <<HELP;
Usage: $0 -w <wiki_id> -a <auth_header_value>

This script fetches Dooray wiki pages recursively and prints them in CSV format.

Options:
  -w  wiki_id          Dooray wiki ID (required)
  -a  auth_header_value  Authorization header value (required)
  -h                  Print this help message

HELP

# Command line options
my %opts;
getopts('w:a:h', \%opts);

# Check for help option
if (exists $opts{'h'}) {
  print $help_message;
  exit;
}

# Validate required options
if (!defined $opts{'w'}) {
  die "Error: Missing required option -w (wiki_id)\n";
}

if (!defined $opts{'a'}) {
  die "Error: Missing required option -a (auth_header_value)\n";
}

# Use provided values or default values
my $wiki_id = $opts{'w'};
my $auth_header_value = $opts{'a'};

# Base URL
my $base_url = "https://api.dooray.com/wiki/v1/wikis/$wiki_id/pages";

# Create a user agent
my $ua = LWP::UserAgent->new;
$ua->default_header('Authorization' => $auth_header_value);
$ua->default_header('Accept' => 'application/json');

# Function to make a request and process the response recursively
sub fetch_pages {
  my ($url, $parent_page_id, $path) = @_;

  # Append parentPageId to the URL if defined
  $url .= "?parentPageId=$parent_page_id" if defined $parent_page_id;

  # Make the HTTP request
  my $response = $ua->get($url);

  # Check if the request was successful
  if ($response->is_success) {
    # Decode the JSON response
    my $data = decode_json($response->decoded_content);

    # Ensure result is defined and is an array reference
    if (defined $data->{result} && ref $data->{result} eq 'ARRAY') {
      # Process the JSON data
      foreach my $page (@{ $data->{result} }) {
        # Create the full path for the current page
        my $current_path = $path ? "$path > $page->{subject}" : $page->{subject};

        # Print the details in CSV format
        my $parent_page_id = defined $page->{parentPageId} ? $page->{parentPageId} : '';
        print encode('UTF-8', "$current_path,$page->{id},$parent_page_id\n");

        # Recursively fetch child pages
        fetch_pages($base_url, $page->{id}, $current_path);
      }
    }
  } else {
    # Print the error message
    die "HTTP GET error: ", $response->status_line;
  }
}

# Print the CSV header
print encode('UTF-8', "Subject (Full Path),ID,Parent Page ID\n");

# Initial call to fetch pages
fetch_pages($base_url, undef, '');
