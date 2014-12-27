package TextShow;
use Mojo::Base 'Mojolicious';

use DBIx::Connector;

has 'dbconn' => sub {	
	my $self = shift;

	my $conn = DBIx::Connector->new( 'dbi:mysql:dbname=sometest;', 'someus', 'Cho8yi4G', {RaiseError => 1, AutoCommit => 0});
	my $dbh = $conn->dbh;
	$dbh->do('set names utf8');	

	return $conn;
};


sub startup {
	my $self = shift;

	my $r = $self->routes;

	# show text 
	$r->get('/')->to('show#all');
	$r->get('/:id' => [id => qr/\d+/])->to('show#someone', id => 2);
	$r->get('/tag/:tag')->to('show#taglist');

	# admin part
	# my $rn = $r->bridge('/admin')->to('admin#check');	
	# $r->get('/form')->to('admin#auth');
	# $r->get('/login')->to('admin#login');
	# $r->get('/logout')->to('admin#logout');
	# $r->get('/admin/')->to('admin#list');
	# $r->get('/admin/:id/edit' => [id => qr/\d+/])->to('admin#edit');	
	# $r->get('/admin/:id/preview' => [id => qr/\d+/])->to('admin#someone');

}



1;
