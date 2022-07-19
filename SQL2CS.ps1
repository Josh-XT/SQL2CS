# Creates a C# class based on your database schema for SQL Server including CRUD and Paginated SQL queries.
param($ProjectPath=$null, $Server=$null, $User=$null, $Pass=$null, $Database=$null, $AuthIssuer=$null, $AuthAudience=$null, $AuthAPIUser=$null, $AuthAPIPass=$null)
$ProjectPath ??= ".\"
if((Test-Path -Path "$($ProjectPath)\Program.cs" -ErrorAction SilentlyContinue) -eq $false) {
    if((Test-Path -Path $ProjectPath -ErrorAction SilentlyContinue) -eq $false) {
        New-Item -ItemType Directory -Path (Split-Path -LiteralPath $ProjectPath) -Name (Split-Path -Path $ProjectPath -Leaf) | Out-Null
    }
    Set-Location "$($ProjectPath)"
    dotnet new web
    dotnet add package "HotChocolate.AspNetCore" -v 12.9.0
    dotnet add package "Microsoft.AspNetCore.Authentication.JwtBearer" -v 5.0.9
    dotnet add package "Microsoft.AspNetCore.Authentication.OpenIdConnect" -v 5.0.0
    dotnet add package "System.IdentityModel.Tokens.Jwt" -v 6.8.0
    dotnet add package "Newtonsoft.Json" -v 13.0.1
    dotnet add package "System.Data.SqlClient" -v 4.8.3
}
Set-Location "$($ProjectPath)"
Remove-Item -Path "Program.cs" -Force -ErrorAction SilentlyContinue
if(Test-Path -Path "$($ProjectPath)\dbconfig.json" -ErrorAction SilentlyContinue) { 
    $Config = (Get-Content "$($ProjectPath)\dbconfig.json" | ConvertFrom-Json)
    $Server = $Config.Server
    $User = $Config.User
    $Pass = $Config.Pass
    $Database = $Config.Database
} else {
    Add-Content -Path "$($ProjectPath)\dbconfig.json" -Value @"
{
    "Server": "$($Server)",
    "User": "$($User)",
    "Pass": "$($Pass)",
    "Database": "$($Database)"
    "AuthIssuer":"$($AuthIssuer)",
    "AuthAudience":"$($AuthAudience)",
    "AuthAPIUser":"$($AuthAPIUser)",
    "AuthAPIPass":"$($AuthAPIPass)"
}
"@
    Add-Content -Path "$($ProjectPath)\.gitignore" -Value "dbconfig.json"
    
}
$Project = $Database.SubString(0,1).ToUpper() + $Database.SubString(1)
Remove-Item -Path "Properties\launchSettings.json" -Force -ErrorAction SilentlyContinue
Add-Content -Path "Properties\launchSettings.json" -Value @"
{
    "`$schema": "http://json.schemastore.org/launchsettings.json",
    "iisSettings": {
      "windowsAuthentication": false,
      "anonymousAuthentication": true,
      "iisExpress": {
        "applicationUrl": "http://localhost:32923",
        "sslPort": 44339
      }
    },
    "profiles": {
      "IIS Express": {
        "commandName": "IISExpress",
        "launchBrowser": true,
        "launchUrl": "https://localhost:5001/graphql",
        "environmentVariables": {
          "ASPNETCORE_ENVIRONMENT": "Development"
        }
      },
      "$($Project)": {
        "commandName": "Project",
        "dotnetRunMessages": "true",
        "launchBrowser": true,
        "launchUrl": "https://localhost:5001/graphql",
        "applicationUrl": "https://localhost:5001",
        "environmentVariables": {
          "ASPNETCORE_ENVIRONMENT": "Development"
        }
      }
    }
  }
"@
(Test-Path -Path "$("Properties\launchSettings.json").old") ? (Write-Host "$("Properties\launchSettings.json") has been updated successfully.") : (Write-Host "$("Properties\launchSettings.json") has been created successfully.")
if((Test-Path -Path "$($ProjectPath)\build.ps1" -ErrorAction SilentlyContinue) -eq $false) { Add-Content -Path "$($ProjectPath)\build.ps1" -Value "$($MyInvocation.MyCommand.Path) -ProjectPath $($ProjectPath)" }
$ConnectionString = "Data Source=$($Server);Initial Catalog=$($Database);Persist Security Info=True;User ID=$($User);Password=$($Pass);"
$TableData = Invoke-SqlCmd -Query "SELECT TABLE_NAME, COLUMN_NAME, IS_NULLABLE, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, ORDINAL_POSITION from INFORMATION_SCHEMA.COLUMNS WHERE TABLE_CATALOG='$($Database)' AND TABLE_SCHEMA='dbo';" -ConnectionString $ConnectionString
$Tables = $TableData.TABLE_NAME | Sort-Object -Unique
Add-Content -Path "Program.cs" -Value @"
// $($Project).cs was automatically generated by the DevXT SQL2CS PowerShell script and should not be modified directly.
// Class was generated based on the SQL database schema for database '$($Database)' on server '$($Server)'.

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Dynamic;
using System.Text;
using System.Linq;
using System.Threading.Tasks;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.HttpsPolicy;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.Options;
using System.Net.Http.Headers;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Linq;
using HotChocolate;

class $($Database.SubString(0,1).ToUpper() + $Database.SubString(1)) {
    private static readonly dynamic DBConfig = JsonConvert.DeserializeObject(File.ReadAllText(@".\dbconfig.json"))!;
    private static string ConnectionString = $"Data Source={DBConfig.Server};Initial Catalog={DBConfig.Database};Persist Security Info=True;User ID={DBConfig.User};Password={DBConfig.Pass};";
    public class Startup {
        public Startup(IConfiguration configuration) {
            Configuration = configuration;
        }
        public IConfiguration Configuration { get; }
        public void ConfigureServices(IServiceCollection services) {
            services.AddControllers();
            services.AddGraphQLServer()
                .AddQueryType<Query>()
                .AddMutationType<Mutation>();
        }
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env) {
            if (env.IsDevelopment()) {
                app.UseDeveloperExceptionPage();
            }
            app.UseHttpsRedirection();
            app.UseRouting();
            app.UseAuthorization();
            app.UseEndpoints(endpoints => {
                endpoints.MapGraphQL();
                endpoints.MapControllers();
            });
        }
    }
    
    public class Program {
        public static void Main(string[] args) {
            CreateHostBuilder(args).Build().Run();
        }
        public static IHostBuilder CreateHostBuilder(string[] args) => Host.CreateDefaultBuilder(args).ConfigureWebHostDefaults(webBuilder => { webBuilder.UseStartup<Startup>(); });
    }
    public class Pagination {
        public int Pages { get; set; }
        public int ResultsPerPage { get; set; }
        public int PageNumber { get; set; }
        public string OrderBy { get; set; }
        public string OrderDirection { get; set; }
        public Pagination(int Pages, int ResultsPerPage, int PageNumber, string OrderBy, string OrderDirection) {
            this.Pages = Pages;
            this.ResultsPerPage = ResultsPerPage;
            this.PageNumber = PageNumber;
            this.OrderBy = OrderBy;
            this.OrderDirection = OrderDirection;
        }
    }
    public class LoginInput {
        public string Email { get; set; }
        public string Password { get; set; }
        public LoginInput(string Email, string Password) {
            this.Email = Email;
            this.Password = Password;
        }
    }
"@
foreach($Table in $Tables) {   
    $TD = $TableData | Where-Object { $_.TABLE_NAME -eq $Table }
    $PluralTable = ($Table.Substring($Table.Length-1) -eq "y") ? "$($Table.Substring(0, $Table.Length-1))ies" : "$($Table)s"
    Add-Content -Path "Program.cs" -Value "    public class $($Table) {"
    $TableKeys = $null
    $ParameterizedKeys = $null
    $UpdateQuery = $null
    $TableJoin = $null
    $FunctionContents = $null
    $FunctionParameters = $null
    $CommaSepVals = $null
    $Parameters = $null
    $FilterParams = $null
    $ReaderParameters = $null
    $SQLParamaters = $null
    $DefineParameters = $null
    $MutationSep = $null
    $GraphQLFunctions = ($null -eq $GraphQLFunctions) ? @"
        public $($Table) Get$($Table)(int ID) {
            $($Table) _$($Table) = null;
            return _$($Table).ReadRecord(ID);
        }
        public $($PluralTable) Get$($PluralTable)(string OrderBy="ID", string OrderDirection = "DESC", int ResultsPerPage=100, int PageNumber=1, string? Filters = null) {
            $($PluralTable) _$($PluralTable) = null;
            return _$($PluralTable).ReadRecords(OrderBy, OrderDirection, ResultsPerPage, PageNumber, Filters);
        }
"@ : @"
$($GraphQLFunctions)
        public $($Table) Get$($Table)(int ID) {
            $($Table) _$($Table) = null;
            return _$($Table).ReadRecord(ID);
        }
        public $($PluralTable) Get$($PluralTable)(string OrderBy="ID", string OrderDirection = "DESC", int ResultsPerPage=100, int PageNumber=1, string? Filters = null) {
            $($PluralTable) _$($PluralTable) = null;
            return _$($PluralTable).ReadRecords(OrderBy, OrderDirection, ResultsPerPage, PageNumber, Filters);
        }
"@
if($Table -eq "User") {
    $FunctionContents = @"
            //var md5 = new MD5CryptoServiceProvider();
            //string MD5Password = md5.ComputeHash(Encoding.UTF8.GetBytes(_Password)).ToString();
            if(_ID == null) {
                string Q = (_AuthKey != null) ? "SELECT TOP 1 ID, Email, Password, AuthKey, LastLogin WHERE Email=@Email AND Password=@Password AND AuthKey=@AuthKey;" : "SELECT TOP 1 ID, Email, Password, AuthKey, LastLogin WHERE Email=@Email AND Password=@Password;";
                using SqlConnection Connection = new(ConnectionString);
                Connection.Open();
                SqlCommand Command = new(Q, Connection);
                Command.Parameters.AddWithValue("@Email", _Email);
                Command.Parameters.AddWithValue("@Password", _Password);
                Command.Parameters.AddWithValue("@AuthKey", _AuthKey);
                SqlDataReader reader = Command.ExecuteReader();
                reader.Read();
                _ID = Convert.ToInt32(reader[0]);
                _LastLogin = Convert.ToDateTime(reader[4]);
                //_Password = MD5Password;
                reader.Close();
                Connection.Close();
            }          
"@
}
    foreach($Row in $TD) {
        $CSharpType = switch($Row.DATA_TYPE) {
            'bigint' { 'long' }
            'binary' { 'byte[]' } 
            'bit' { 'bool' }
            'char' { 'string' }
            'date' { 'DateTime' } 
            'datetime' { 'DateTime' }
            'datetime2' { 'DateTime' }
            'datetimeoffset' { 'DateTimeOffset' }
            'decimal' { 'decimal' }
            'float' { 'float' }
            'image' { 'byte[]' }
            'int' { 'int' }
            'money' { 'decimal' }
            'nchar' { 'char' }
            'ntext' { 'string' } 
            'numeric' { 'decimal' }
            'nvarchar' { 'string' }
            'real' { 'double' }
            'smalldatetime' { 'DateTime' }
            'smallint' { 'short' }
            'smallmoney' { 'decimal' }
            'text' { 'string' }
            'time' { 'TimeSpan' }
            'timestamp' { 'DateTime' }
            'tinyint' { 'byte' }
            'uniqueidentifier' { 'Guid' }
            'varbinary' { 'byte[]' }
            'varchar' { 'string' }
        }
        $Conversion = switch($CSharpType) {
            'string' { 'ToString' }
            'DateTime' { 'ToDateTime' } 
            'int' { 'ToInt32' }
        }
        $NullableType = ($Row.IS_NULLABLE -ne "NO") ? "$($CSharpType)?" : $CSharpType
        if($Row.COLUMN_NAME -eq "ID" -AND $Table -eq "User") { $NullableType = "$($CSharpType)?" }
        Add-Content -Path "Program.cs" -Value "         public $($NullableType) $($Row.COLUMN_NAME) { get; set; }"
        if($Row.CHARACTER_MAXIMUM_LENGTH -is [int]) {
            Add-Content -Path "Program.cs" -Value "            public int $($Row.COLUMN_NAME)MaxLength = $($Row.CHARACTER_MAXIMUM_LENGTH);"
        }
        $FunctionParameters = ($null -eq $FunctionParameters) ? "$($NullableType) _$($Row.COLUMN_NAME)" : "$($FunctionParameters), $($NullableType) _$($Row.COLUMN_NAME)"
        $CommaSepVals = ($null -eq $CommaSepVals) ? "_$($Row.COLUMN_NAME)" : "$($CommaSepVals), _$($Row.COLUMN_NAME)"
        $DefineParameters = ($null -eq $DefineParameters) ? "                $($NullableType) _$($Row.COLUMN_NAME) = Convert.$($Conversion)(Parameters[""@$($Row.COLUMN_NAME)""]);" : "$($DefineParameters)`r`n                $($NullableType) _$($Row.COLUMN_NAME) = Convert.$($Conversion)(Parameters[""@$($Row.COLUMN_NAME)""]);"
        $NullableFunctionParameters = ($null -eq $NullableFunctionParameters) ? "$($CSharpType)? $($Row.COLUMN_NAME)" : "$($NullableFunctionParameters), $($CSharpType)? $($Row.COLUMN_NAME)"
        $RowPos = (($Row.ORDINAL_POSITION) - 1)
        $ReaderParameters = ($null -eq $ReaderParameters) ? "                $($NullableType) _$($Row.COLUMN_NAME) = Convert.$($Conversion)(reader[$(($RowPos))]);" : "$($ReaderParameters)`r`n                $($NullableType) _$($Row.COLUMN_NAME) = Convert.$($Conversion)(reader[$(($RowPos))]);";
        $SQLParamaters = ($null -eq $SQLParamaters) ? "            Command.Parameters.AddWithValue(""@$($Row.COLUMN_NAME)"", _$($Row.COLUMN_NAME).ToString());" : "$($SQLParamaters)`r`n            Command.Parameters.AddWithValue(""@$($Row.COLUMN_NAME)"", _$($Row.COLUMN_NAME).ToString());"
        
        $FunctionContents = ($null -eq $FunctionContents) ? "            this.$($Row.COLUMN_NAME) = _$($Row.COLUMN_NAME);" : "$($FunctionContents)`r`n            this.$($Row.COLUMN_NAME) = _$($Row.COLUMN_NAME);"
        $TableKeys = ($null -eq $TableKeys) ? $Row.COLUMN_NAME : "$($TableKeys), $($Row.COLUMN_NAME)"
        $ParameterizedKeys = ($null -eq $ParameterizedKeys) ? "@$($Row.COLUMN_NAME)" : "$($ParameterizedKeys), @$($Row.COLUMN_NAME)"
        $MutationSep = ($null -eq $MutationSep) ? "Convert.$($Conversion)(Parameters[""@$($Row.COLUMN_NAME)""])" : "$($MutationSep), Convert.$($Conversion)(Parameters[""@$($Row.COLUMN_NAME)""])"
        $UpdateQuery = ($null -eq $UpdateQuery) ? "$($Row.COLUMN_NAME)=@$($Row.COLUMN_NAME)" : "$($UpdateQuery), $($Row.COLUMN_NAME)=@$($Row.COLUMN_NAME)"
        $Parameters = ($null -eq $Parameters) ? "            Parameters.Add(""@$($Row.COLUMN_NAME)"",_$($Row.COLUMN_NAME).ToString());" : "$($Parameters)`r`n            Parameters.Add(""@$($Row.COLUMN_NAME)"",_$($Row.COLUMN_NAME).ToString());"
        $FilterParams = @"
$($FilterParams)
                        if(FilterSplit[0]=="$($Row.COLUMN_NAME)") {
                            Parameters.Add("@$($Row.COLUMN_NAME)", FilterSplit[1]);
                            NewFilters = $"$($Row.COLUMN_NAME){ConditionType}{FilterSplit[1]}";
                        }
"@
    }
    $Joins = $Tables | where-object { $_.IndexOf($Table) -eq 0 -AND $_ -ne $Table}
    foreach($Join in $Joins) {
        $JoinData = $Tables | where-object { $_.TABLE_NAME -eq $Join }
        $JoinTableKeys = $null
        foreach($JoinRow in $JoinData) {
            $JoinTableKeys = ($null -eq $JoinTableKeys) ? $JoinRow.COLUMN_NAME : $JoinTableKeys + ",$($JoinRow.COLUMN_NAME)"
        }
        $SplitJoin = $Join.SubString($Table.Length, $Join.Length - $Table.Length)
        $TableJoin += ", (SELECT $($JoinTableKeys) FROM dbo.$($Join) WHERE dbo.$($Join).$($SplitJoin)ID=ID) AS $($SplitJoin)"
    }
    $Mutations += "        public $($Table) $($Table)Mutation($($FunctionParameters)) {`r`n            $($Table) _$($Table) = new $($Table)($($CommaSepVals));`r`n            return (_$($Table).ReadRecord(_ID) != null) ? _$($Table).UpdateRecord($($CommaSepVals)) : _$($Table).CreateRecord($($CommaSepVals));`r`n        }`r`n"
    Add-Content -Path "Program.cs" -Value @"
        public $($Table)? CreateRecord ($($FunctionParameters)) {
            Dictionary<string, string?>? Parameters = new();
$($Parameters)
            string Q = "INSERT INTO dbo.$($Table) ($($TableKeys)) VALUES ($($ParameterizedKeys);";
            using SqlConnection Connection = new(ConnectionString);
            Connection.Open();
            SqlCommand Command = new(Q, Connection);
$($SQLParamaters)
            Command.ExecuteNonQuery();
            Connection.Close();
            $($Table) _$($Table) = new($($CommaSepVals));
            return _$($Table).ReadRecord(_$($Table).ID);
        }
        public $($Table)? ReadRecord (int? ID) {
            if(ID != null) {
                string Q = "SELECT TOP 1 $($TableKeys)$($TableJoin) FROM dbo.$($Table) WHERE ID=@ID ORDER BY ID DESC;";
                using SqlConnection Connection = new(ConnectionString);
                Connection.Open();
                SqlCommand Command = new(Q, Connection);
                Command.Parameters.AddWithValue("@ID", ID.ToString());
                SqlDataReader reader = Command.ExecuteReader();
                reader.Read();
$($ReaderParameters)
                reader.Close();
                Connection.Close();
                $($Table) _$($Table) = new $($Table)($($CommaSepVals));
                return _$($Table);
            } else {
                return null;
            }
        }
        public $($Table)? UpdateRecord ($($FunctionParameters)) {
            Dictionary<string, string?>? Parameters = new();
$($Parameters)
            string Q = "UPDATE dbo.$($Table) SET $($UpdateQuery) WHERE ID=@ID;";
            using SqlConnection Connection = new(ConnectionString);
            Connection.Open();
            SqlCommand Command = new(Q, Connection);
$($SQLParamaters)
            Command.ExecuteNonQuery();
            Connection.Close();
            $($Table) _$($Table) = new($($CommaSepVals));
            return _$($Table).ReadRecord(_$($Table).ID);
        }
        public void DeleteRecord (int ID) {
            string Q = $(($null -ne ($TD | where-object { $_.COLUMN_NAME = "Active" })) ? "$""UPDATE dbo.$($Table) SET Active=0 WHERE ID={ID};""" : "$""DELETE FROM dbo.$($Table) WHERE ID={ID};""");
            using SqlConnection Connection = new(ConnectionString);
            Connection.Open();
            SqlCommand Command = new(Q, Connection);
            Command.ExecuteNonQuery();
            Connection.Close();
        }
        public $($Table) ($($FunctionParameters)) {
$($FunctionContents)
        }
    }
    public class $($PluralTable) {
        public $($PluralTable)? ReadRecords (string OrderBy = "ID", string OrderDirection = "DESC", int ResultsPerPage = 100, int PageNumber = 1, string? Filters = null) {
            PageNumber = (PageNumber == 0) ? 1 : PageNumber;
            Dictionary<string, string?>? Parameters = new();
            List<$($Table)>? _$($PluralTable) = new();
            string[] Conditions = Filters.Split(",");
            string NewFilters = "";
            string[] ConditionTypes = {"=",">","<",">=","<="};
            foreach(string ConditionType in ConditionTypes) {
                foreach(string Condition in Conditions) {
                    string[] FilterSplit = Condition.Split(ConditionType);
$($FilterParams)
                }
            }
            Filters = NewFilters.Replace(", ", ",").Replace(" ,", ",").Replace(",", " AND ");
            string Q = "SELECT (SELECT (SELECT TOP @ResultsPerPage $($TableKeys)$($TableJoin) from dbo.$($Table) WHERE ID NOT IN (SELECT TOP @TOPIN ID FROM dbo.$($Table))@FILTERS ORDER BY @OrderBy @OrderDirection) AS Data), SELECT (SELECT CEILING(CAST(COUNT(ID) as decimal(10,2))/@ResultsPerPage) AS Pages, @ResultsPerPage AS ResultsPerPage, @PageNumber AS PageNumber FROM dbo.$($Table) WHERE ID NOT IN (SELECT TOP @TOPIN ID FROM dbo.$($Table))@FILTERS) AS Meta;";
            Q = Q.Replace("@ResultsPerPage", (ResultsPerPage >= 500) ? "500" : ResultsPerPage.ToString())
                .Replace("@OrderBy", OrderBy)
                .Replace("@OrderDirection", OrderDirection)
                .Replace("@PageNumber", PageNumber.ToString())
                .Replace("@TOPIN", ((PageNumber > 1) ? (PageNumber * ResultsPerPage).ToString() : "0"))
                .Replace("@FILTERS", ((Filters == null) ? "ID=@ID" : Filters));
            using SqlConnection Connection = new(ConnectionString);
            Connection.Open();
            SqlCommand Command = new(Q, Connection);
            if (Parameters != null) {
                foreach (dynamic p in Parameters.Keys) {
                    Command.Parameters.AddWithValue($"@{p.ToString()}", Parameters[p].ToString());
                }
            }
            SqlDataReader reader = Command.ExecuteReader();
            reader.Read();
$($ReaderParameters)
            _$($PluralTable).Add(new $($Table)($($CommaSepVals)));
            reader.Close();
            Connection.Close();
            return new $($PluralTable)(_$($PluralTable), new Pagination(Convert.ToInt32(Parameters["Pages"]), ResultsPerPage, PageNumber, OrderBy, OrderDirection));
        }
        public Pagination? Meta { get; set; }
        public List<$($Table)> Data { get; set; }
        public $($PluralTable)(List<$($Table)> Data, Pagination? Meta) {
            this.Data = Data;
            this.Meta = Meta;
        }
    }
"@
}
Add-Content -Path "Program.cs" -Value @"
    public class Query {
        public User? UserAuth(string Email, string Password) {
            User _User = new(null, Email, Password, null, null);
            if(_User.ReadRecord(_User.ID) != null) {
                HttpClient InternalHttpClient = new();
                var Form = new FormUrlEncodedContent(new Dictionary<string, string> { 
                    { "client_id", DBConfig.AuthAPIUser }, 
                    { "password", DBConfig.AuthAPIPass }, 
                    { "audience", DBConfig.AuthAudience }, 
                    { "grant_type", "client_credentials" } 
                });
                var TokenMessage = InternalHttpClient.PostAsync(DBConfig.AuthIssuer, Form);
                string ApiKey = (string?)JObject.Parse(TokenMessage.Result.Content.ReadAsStringAsync().Result)["access_token"];
                _User.UpdateRecord(_User.ID, _User.Email, _User.Password, ApiKey, DateTime.Now);
                return _User;
            }
            return null;
        }
$($GraphQLFunctions)
    }
    public class Mutation {
$($Mutations)
    }
"@
Add-Content -Path "Program.cs" -Value "}"
(Test-Path -Path "$("Program.cs").old") ? (Write-Host "$("Program.cs") has been updated successfully.") : (Write-Host "$("Program.cs") has been created successfully.")
dotnet build