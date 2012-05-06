$(document).ready(function(){
	$(function() {	
		$("#maininput, .autocomplete").autocomplete({
			source: "/quick",
			minLength: 2,	   
			focus: function(event, ui) { return false; },
	   
		});
	});
	$('input[title!=""]').hint();
	$('#search, #go').button();
	RPXNOW.overlay = true;
	RPXNOW.language_preference = 'en';
});