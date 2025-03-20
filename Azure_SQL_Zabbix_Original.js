var AzureDB = {
	params: {},
	token: null,

	setParams: function (params) {
		['app_id', 'password', 'tenant_id', 'subscription_id', 'resource_id'].forEach(function (field) {
			if (typeof params !== 'object' || typeof params[field] === 'undefined' || params[field] === '') {
				throw 'Required param is not set: ' + field + '.';
			}
		});

		AzureDB.params = params;
	},


	request: function (url, data) {
		if (typeof data === 'undefined' || data === null) {
			data = '';
		}

		var response, request = new HttpRequest();
		if (typeof AzureDB.params.proxy !== 'undefined' && AzureDB.params.proxy !== '') {
			request.setProxy(AzureDB.params.proxy);
		}
		if (AzureDB.token) {
			request.addHeader('Accept: application/json');
			request.addHeader('Authorization: Bearer ' + AzureDB.token);
		}

		Zabbix.log(4, '[ Azure ] Sending request: ' + url);

		if (data !== '') {
			request.addHeader('Content-Type: application/x-www-form-urlencoded');
			response = request.post(url, data);
		}
		else {
			response = request.get(url);
		}

		Zabbix.log(4, '[ Azure ] Received response with status code ' + request.getStatus() + ': ' + response);

		if (request.getStatus() !== 200 || response === null) {
			throw 'Request failed with status code ' + request.getStatus() + ': ' + response;
		}

		try {
			return JSON.parse(response);
		}
		catch (error) {
			throw 'Failed to parse response received from API.';
		}
	}

};

var metrics = [
	'cpu_percent',
	'physical_data_read_percent',
	'log_write_percent',
	'storage',
	'connection_successful',
	'connection_failed',
	'blocked_by_firewall',
	'deadlock',
	'storage_percent',
	'xtp_storage_percent',
	'workers_percent',
	'sessions_percent',
	'sessions_count',
	'cpu_limit',
	'cpu_used',
	'sqlserver_process_core_percent',
	'sqlserver_process_memory_percent',
	'tempdb_data_size',
	'tempdb_log_size',
	'tempdb_log_used_percent',
	'allocated_data_storage'
],
	day_metrics = 'full_backup_size_bytes,diff_backup_size_bytes,log_backup_size_bytes',
	prepared_metrics = [],
	data = {};
	data['errors'] = {};
	data['metrics'] = {};

try {
	AzureDB.setParams(JSON.parse(value));

	try {
		result = AzureDB.request(
			'https://login.microsoftonline.com/' + encodeURIComponent(AzureDB.params.tenant_id) + '/oauth2/token',
			'grant_type=client_credentials&resource=' + encodeURIComponent('https://management.azure.com/') + '&client_id=' + encodeURIComponent(AzureDB.params.app_id) + '&client_secret=' + encodeURIComponent(AzureDB.params.password)
		);

		if ('access_token' in result) {
			AzureDB.token = result['access_token'];
		} else {
			throw 'Auth response does not contain access token.';
		}
	}
	catch (error) {
		data.errors.auth = error.toString();
	}

	if (!('auth' in data.errors)) {
		try {
			health = AzureDB.request('https://management.azure.com' + AzureDB.params.resource_id + '/providers/Microsoft.ResourceHealth/availabilityStatuses?api-version=2020-05-01');
			if ('value' in health && Array.isArray(health.value) && health.value.length > 0 && 'properties' in health.value[0] && typeof health.value[0].properties === 'object') {
				data.health = health.value[0].properties;
			}
		}
		catch (error) {
			data.errors.health = error.toString();
		}

		for (var i = 0; i < metrics.length; i += 20) {
			var chunk = metrics.slice(i, i + 20);

			prepared_metrics.push(
				chunk.map(function (element) {
					return encodeURIComponent(element);
				}).join(',')
			);
		}

		start_date = new Date((new Date().getTime()) - 300000).toISOString().replace(/\.\d+/, '');
		end_date = new Date().toISOString().replace(/\.\d+/, '');

		for (var j in prepared_metrics) {
			try {
				metrics_data = AzureDB.request('https://management.azure.com' + AzureDB.params.resource_id + '/providers/Microsoft.Insights/metrics?metricnames=' + prepared_metrics[j] + '&timespan=' + encodeURIComponent(start_date) + '/' + encodeURIComponent(end_date) + '&api-version=2021-05-01');
				if ('value' in metrics_data && Array.isArray(metrics_data.value) && metrics_data.value.length > 0) {
					for (k in metrics_data.value) {
						if ('name' in metrics_data.value[k] && typeof metrics_data.value[k].name === 'object' && 'value' in metrics_data.value[k].name && typeof metrics_data.value[k].name.value === 'string' && 'timeseries' in metrics_data.value[k] && Array.isArray(metrics_data.value[k].timeseries) && metrics_data.value[k].timeseries.length > 0 && 'data' in metrics_data.value[k].timeseries[0] && Array.isArray(metrics_data.value[k].timeseries[0].data) && metrics_data.value[k].timeseries[0].data.length > 0) {
							data.metrics[metrics_data.value[k].name.value.replace(/(\s|\/)+/g, '')] = metrics_data.value[k].timeseries[0].data[metrics_data.value[k].timeseries[0].data.length - 1];
						}
					}
				}
			}
			catch (error) {
				data.errors[prepared_metrics[j]] = error.toString();
			}
		}
		start_date = new Date((new Date().getTime()) - 86400000).toISOString().replace(/\.\d+/, '');
		end_date = new Date().toISOString().replace(/\.\d+/, '');
		try {
			metrics_data = AzureDB.request('https://management.azure.com' + AzureDB.params.resource_id + '/providers/Microsoft.Insights/metrics?metricnames=' + day_metrics + '&timespan=' + encodeURIComponent(start_date) + '/' + encodeURIComponent(end_date) + '&api-version=2021-05-01');
			if ('value' in metrics_data && Array.isArray(metrics_data.value) && metrics_data.value.length > 0) {
				for (l in metrics_data.value) {
					if ('name' in metrics_data.value[l] && typeof metrics_data.value[l].name === 'object' && 'value' in metrics_data.value[l].name && typeof metrics_data.value[l].name.value === 'string' && 'timeseries' in metrics_data.value[l] && Array.isArray(metrics_data.value[l].timeseries) && metrics_data.value[l].timeseries.length > 0 && 'data' in metrics_data.value[l].timeseries[0] && Array.isArray(metrics_data.value[l].timeseries[0].data) && metrics_data.value[l].timeseries[0].data.length > 0) {
						data.metrics[metrics_data.value[l].name.value.replace(/(\s|\/)+/g, '')] = metrics_data.value[l].timeseries[0].data[metrics_data.value[l].timeseries[0].data.length - 1];
					}
				}
			}
		}
		catch (error) {
			data.errors[day_metrics] = error.toString();
		}
	}
}
catch (error) {
	data.errors.params = error.toString();
}

if (Object.keys(data.errors).length !== 0) {
	errors = 'Failed to receive data:';
	for (var error in data.errors) {
		errors += '\n' + error + ' : ' + data.errors[error];
	}
	data.errors = errors;
}
else {
	data.errors = '';
}

return JSON.stringify(data);