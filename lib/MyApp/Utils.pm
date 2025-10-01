package MyApp::Utils;
use Exporter 'import';
use POSIX 'ceil';

our @EXPORT_OK = qw(ceil format_date format_datetime truncate_string);

sub format_date {
    my ($timestamp) = @_;
    return scalar localtime $timestamp;
}

sub format_datetime {
    my ($timestamp) = @_;
    if ($timestamp) {
        my ($date, $time) = split / /, $timestamp;
        return "$date<br><small>$time</small>";
    }
    return $timestamp;
}

sub truncate_string {
    my ($string, $length) = @_;
    $length ||= 50;
    
    if (length($string) > $length) {
        return substr($string, 0, $length) . '...';
    }
    return $string;
}

1;