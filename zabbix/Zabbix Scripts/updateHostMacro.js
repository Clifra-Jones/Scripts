var obj = JSON.parse(value);
const hostIp = obj.hostIp;
const hostName = obj.hostName;
//const user = "APIUser";
//const userPassword = "c7Z14D^Nyc";
//const APIurl = "http://" + hostIp + ":8080/Auth";
const zabbixUrl = 'http://AWSZABBIX02.bbc.local/zabbix/api_jsonrpc.php';
const zabbixUser = "APIUser";
const zabbixPassword = "c7Z14D^Nyc";
const macroName = '{$' + 'CORES' + '}';


// Get authentication Token from REST API
// var reqDivaltoApiAuth = new CurlHttpRequest();
// reqDivaltoApiAuth.AddHeader('Content-Type: application/json');
// var json_divalto_auth_body = {
//     user: user,
//     password: userPassword
// };
// var json_divalto_auth_post_data = JSON.stringify(json_divalto_auth_body);
// var response_divalto_auth = JSON.parse(reqDivaltoApiAuth.Post(APIurl, json_divalto_auth_post_data));
// var macroValue = response_divalto_auth.access_token;

// Authenticate with Zabbix API
var reqZabbixApiAuth = new CurlHttpRequest();
reqZabbixApiAuth.AddHeader('Content-Type: application/json');
var json_authZabbixApi_body = {
    jsonrpc: '2.0',
    method: 'user.login',
    params: {
        user: zabbixUser,
        password: zabbixPassword
    },
    id: 1,
    auth: null
};
var json_authZabbixApi_post_data = JSON.stringify(json_authZabbixApi_body);
var response_authZabbixApi = JSON.parse(reqZabbixApiAuth.Post(zabbixUrl, json_authZabbixApi_post_data));
var zabbixToken = response_authZabbixApi.result;

// Get host ID for the current host
var reqGetHostId = new CurlHttpRequest();
reqGetHostId.AddHeader('Content-Type: application/json');
var json_host_body = {
    jsonrpc: '2.0',
    method: 'host.get',
    params: {
        output: 'extend',
        filter: {
            host: hostName
        }
    },
    id: 1,
    auth: zabbixToken
};
var json_host_post_data = JSON.stringify(json_host_body);
var response_host = JSON.parse(reqGetHostId.Post(zabbixUrl, json_host_post_data));
var hostId = response_host.result[0].hostid;

// Get the ItemId for the Number of Cores item
var reqGetItemId = new CurlHttpRequest();
reqGetItemId.AddHeader('ContentTypeL application/json');
var json_host_body = {
    jsonrpc: '2.0',
    method: 'host.get'
    params: {
        
    }
}

//Get Number of cores for this host

// Get macro ID
var reqGetMacroId = new CurlHttpRequest();
reqGetMacroId.AddHeader('Content-Type: application/json');
var json_macro_body = {
    jsonrpc: '2.0',
    method: 'usermacro.get',
    params: {
        output: 'extend',
        filter: {
            macro: macroName,
            hostid: hostId
        }
    },
    id: 1,
    auth: zabbixToken
};
var json_macro_post_data = JSON.stringify(json_macro_body);
var response_macro = JSON.parse(reqGetMacroId.Post(zabbixUrl, json_macro_post_data));
var macroId = response_macro.result[0] ? response_macro.result[0].hostmacroid : null;

if (!macroId) {
 // create macro value with the API REST token
    var reqCreateMacro = new CurlHttpRequest();
    reqCreateMacro.AddHeader('Content-Type: application/json');
    var json_macro_create_body = {
        jsonrpc: '2.0',
        method: 'usermacro.create',
        params: {
            hostid: hostId,
            macro: macroName,
            value: macroValue
        },
        id: 1,
        auth: zabbixToken
    };
    var json_macro_create_post_data = JSON.stringify(json_macro_create_body);
    reqCreateMacro.Post(zabbixUrl, json_macro_create_post_data);
    return "macro created";
} else {
// Update macro macro value with the API REST token
    var reqUpdateMacro = new CurlHttpRequest();
    reqUpdateMacro.AddHeader('Content-Type: application/json');
    var json_macro_update_body = {
        jsonrpc: '2.0',
        method: 'usermacro.update',
        params: {
            hostmacroid: macroId,
            value: macroValue
        },
        id: 1,
        auth: zabbixToken
    };
    var json_macro_update_post_data = JSON.stringify(json_macro_update_body);
    reqUpdateMacro.Post(zabbixUrl, json_macro_update_post_data);
    return "macro updated";
}

// Log out from Zabbix API
var reqLogout = new CurlHttpRequest();
reqLogout.AddHeader('Content-Type: application/json');
var json_logout_body = {
    jsonrpc: '2.0',
    method: 'user.logout',
    params: {},
    id: 1,
    auth: zabbixToken
};
var json_logout_post_data = JSON.stringify(json_logout_body);
reqLogout.Post(zabbixUrl, json_logout_post_data);