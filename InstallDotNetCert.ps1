using namespace System.Security.Cryptography.X509Certificates
$Store = [X509Store]::New('My','CurrentUser','ReadWrite')
$Store.Add([X509Certificate2]::New('../../Downloads/AzureCert.pfx','10campus',[X509KeyStorageFlags]::PersistKeySet))
$Store.Dispose()