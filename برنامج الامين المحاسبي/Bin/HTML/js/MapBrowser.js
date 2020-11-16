function setCustomerMarker(map, location, name, phone, work) {
		var marker = new google.maps.Marker({ position: location,
		icon:'Images/customer.png' });
		marker.setMap(map);
		var infowindow = new google.maps.InfoWindow({ content: '<div dir ="rtl">' + name + '<br>' + phone + '<br>' + work +'</div>' });
		infowindow.open(map,marker);
		google.maps.event.addListener(marker, 'click', function() { infowindow.open(map,marker); });
};

function setPlanMarker(map, location, time) {
    var marker = new google.maps.Marker({
        position: location,
        icon: 'Images/truck.png'
    });
    marker.setMap(map);
    var infowindow = new google.maps.InfoWindow({ content: '<div dir ="rtl">' + time + '</div>' });
    infowindow.open(map, marker);
    google.maps.event.addListener(marker, 'click', function () { infowindow.open(map, marker); });
};

function setMarker(map, location, date, endDate) {
    var marker = new google.maps.Marker({
        position: location
    });
    marker.setMap(map);
    var infowindow = new google.maps.InfoWindow({ content: '<div dir ="rtl">' + date + '<br>' + endDate +'</div>' });
    google.maps.event.addListener(marker, 'click', function () { infowindow.open(map, marker); });
};

// Use the DOM setInterval() function to change the offset of the symbol
// at fixed intervals.
function animateCircle(line) {
    var count = 0;
    window.setInterval(function () {
        var icons = line.get('icons');
        if (count != 199) {
            count = (count + 1) % 200;
            icons[0].offset = (count / 2) + '%';
        }
        else {
            icons[0].offset = 100 + '%';
        }
        line.set('icons', icons);
    }, 50);
}
