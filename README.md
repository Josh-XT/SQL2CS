## Project Incomplete and No longer maintained!

Shortly after starting on this project, I learned of [Hasura GraphQL Engine](https://github.com/hasura/graphql-engine) which offered solutions to all of the remaining issues that I hadn't worked out with this in a much nicer packaging. 

This is not an optimal way to do what I was doing, it was a project for fun that demonstrates the ability to create a `C#` / `ASP.NET Core` GraphQL web API with a ``PowerShell`` script based on information in a selected database.  It was a good project that helped me better understand cross-language code generation and the power of ``PowerShell`` and ``dotnetcli``.

Anyone is welcome to use this code for anything they would like.  I am not responsible for any vulnerabilities that may be found in the code if there ever are any, this repository is archived and unmaintained.

## What is this?

Basically, it is a PowerShell script that takes your `Microsoft SQL Server` database information then creates a `C#` / `ASP.NET Core` back end project with JWT authentication and it automatically builds all GraphQL Queries and Mutations based on your database.  I got tired of having to change code every time anything changed in the database, so I created this to make any code changes needed after making SQL Server changes in the database to be as easy as running a PowerShell script.

I intend to add a switch to this for other types of databases as well, but it is currently only set up to work with Microsoft SQL Server.

## SQL2CS Script Usage

`.\SQL2CS.ps1 -ProjectPath "/Path/To/Project" -User "SQLUSER" -Pass "SQLPASS" -Server "SQLSERVER" -Database "SQLDATABASE"`

Replace `/Path/To/Project`, `SQLUSER`, `SQLPASS`, `SQLSERVER`, `SQLDATABASE` with your information to automatically generate a C# Class file modeling the class based on the SQL database schema and building CRUD operations and creating all GraphQL queries and mutations  automatically for each table.

This will create a brand new C# project with all generated code in `Program.cs`. It will automatically capitalize the first letter of your database name if it is not already capitalized to maintain PascalCase in the code.

After you run the script for the first time, every time after that, you will be able to run `./build.ps1` from your project path to rebuild the Program.cs after any changes in the database schema.  It references back to where `SQL2CS.ps1` is run from, so you will want to keep the `SQL2CS.ps1` in your repo location.

## Rules To Follow For Designing The Database

**Every table must have an auto incrementing `ID` int set as primary key**

**Table names should be in PascalCase to determine Parent/Child relationships for automated joins.**

_Example: `Device` or `DeviceDisk` would be proper use._


**Table names should always be singular, never plural.**

_Example: `Device` should be the table name rather than `Devices` in the database._


**Child tables should be named like `ParentChild` for automated joins.**

_Example: if the Parent is `Device` and the Child is `Disk`, the child table should be named `DeviceDisk` to be joined automatically._


**Foreign ID's should always be named `ParentID` for automated joins.**

_Example: `DeviceID` for something referencing a Device record from `DeviceDisk` table._


**If you do not want items to be deactivated rather than deleted with the DeleteRecord operation, add an int called `Active` as a column in the table.**

## User table schema

User table schema must start with these three fields, you should create tables to relate to `Users.ID` rather than changing anything with this table.

`ID` - `int`, `auto-incrementing`

`Email` - `varchar(999)`, `not null`

`Password` - `varchar(999)`, `not null`


## Filters for ReadRecords (Plural)

Filters are comma separated values.  Currently supports `=`, `>`, `<`, `>=`, `<=` operators.

_Example: `Filters` set to `ID=4,SeralNumber='abc123',Manufacturer='TestVendor'` on a `Device` table would confirm these parameters were all real and then add them to the `WHERE` SQL statement._

## Config file

The `dbconfig.json` file is automatically created when the script is run for the first time with the database details provided.

Replace `SQLUSER`, `SQLPASS`, `SQLSERVER`, `SQLDATABASE` with your database information to have the script pull it in automatically without needing to pass in the parameters.

<code>{
    "User": "SQLUSER",
    "Pass": "SQLPASS",
    "Server": "SQLSERVER",
    "Database": "SQLDATABASE"
}</code>
