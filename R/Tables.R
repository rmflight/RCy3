# ==============================================================================
# Functions for managing TABLE columns and table column functions, like map and
# rename, as well as loading and extracting table data in Cytoscape.
# 
# ------------------------------------------------------------------------------
#' @title Delete a table column 
#'
#' @description Delete a column from node, edge or network tables.
#' @param column Name of the column to delete
#' @param table Name of table, e.g., node (default), edge, network
#' @param namespace Namespace of table. Default is "default".
#' @param network (optional) Name or SUID of the network. Default is the "current" 
#' network active in Cytoscape.
#' @param base.url (optional) Ignore unless you need to specify a custom domain,
#' port or version to connect to the CyREST API. Default is http://localhost:1234
#' and the latest version of the CyREST API supported by this version of RCy3.
#' @return A \code{data.frame} of column values
#' @examples
#' \donttest{
#' deleteTableColumn('node','group')
#' }
#' @export
deleteTableColumn <- function(column ,
                              table = 'node',
                              namespace = 'default',
                              network = NULL, 
                              base.url = .defaultBaseUrl) {
    net.suid <- getNetworkSuid(network)
    tbl = paste0(namespace, table)
    cyrestDELETE(paste('networks',net.suid,'tables',tbl,'columns',as.character(column),sep="/"),
                 base.url = base.url)
}


# ------------------------------------------------------------------------------
#' @title Get table column values
#'
#' @description Retrieve one or more columns of data from node, edge or network
#' tables.
#' @details The 'SUID' column is always retrieved along with specified columns. 
#' The 'SUID' values are used as \code{row.names} in the returned \code{data.frame}. 
#' @param table name of table, e.g., node (default), edge, network
#' @param columns names of columns to retrieve values from as list object or comma-separated list; default is all columns
#' @param namespace namespace of table; default is "default"
#' @param network (optional) Name or SUID of the network. Default is the "current" 
#' network active in Cytoscape.
#' @param base.url (optional) Ignore unless you need to specify a custom domain,
#' port or version to connect to the CyREST API. Default is http://localhost:1234
#' and the latest version of the CyREST API supported by this version of RCy3.
#' @return A \code{data.frame} of column values
#' @examples
#' \donttest{
#' getTableColumns()
#' getTableColumns('node','group')
#' }
#' @export
getTableColumns <- function(table = 'node',
                             columns = NULL,
                             namespace = 'default',
                             network = NULL,
                             base.url = .defaultBaseUrl) {
    suid = getNetworkSuid(network)
    
    #column information (names and types)
    table.col.info <- getTableColumnTypes(table, namespace, network, base.url)
    table.col.list <- names(table.col.info)
    
    #all columns
    if (is.null(columns))
        columns = table.col.list
    
    #handle comma separated lists and list objects
    col.list = columns
    if (length(col.list) == 1)
        col.list = unlist(strsplit(columns, ","))
    
    #get suid column first
    tbl = paste0(namespace, table)
    res.names <- cyrestGET(paste('networks',suid,'tables',tbl,'columns','SUID',sep="/"),
                           base.url = base.url)
    df = data.frame(row.names = res.names$values)
    
    #then append other requested columns
    for (col in col.list) {
        #check for column names
        if (!col %in% table.col.list) {
            cat(sprintf("Error: Column %s not found in %s table \n", col, table))
            next()
        }
        #isolate column type
        table.col.type <- table.col.info[col]
        res.col <- cyrestGET(paste('networks',suid,'tables',tbl,'columns',col, sep="/"),
                             base.url = base.url)
        #convert NULL to NA, then unlist
        cvv <- unlist(lapply(res.col$values, function(x)
            ifelse(is.null(x), NA, x)))
        if (length(res.names$values) == length(cvv)) {
            for (i in 1:length(res.names$values)) {
                switch(table.col.type, 
                       "Double"={
                           df[i, col] <- as.numeric(cvv[i])
                       },
                       "Long"=,
                       "Integer"={
                           df[i, col] <- as.integer(cvv[i])
                       },
                       "Boolean"={
                           df[i, col] <- as.logical(cvv[i])
                       },{
                           df[i, col] <- as.character(cvv[i])
                       }
                )
            }
        } else {
            print(
                "Warning: Requested column has missing values. Returning single column without row.names..."
            )
            df2 = data.frame(col = unlist(res.col$values))
            return(df2)
        }
    }
    return(df)
}

# ------------------------------------------------------------------------------
#' @title Get Table Column Names 
#'
#' @description Retrieve the names of all columns in a table
#' @param table name of table, e.g., node, edge, network; default is "node"
#' @param namespace namespace of table, e.g., default
#' @param network (optional) Name or SUID of the network. Default is the "current" 
#' network active in Cytoscape.
#' @param base.url (optional) Ignore unless you need to specify a custom domain,
#' port or version to connect to the CyREST API. Default is http://localhost:1234
#' and the latest version of the CyREST API supported by this version of RCy3.
#' @return list of column names
#' @examples
#' \donttest{
#' getTableColumnNames()
#' getTableColumnNames('edge')
#' getTableColumnNames('network')
#' }
#' @export
getTableColumnNames <-  function(table = 'node',
                                 namespace = 'default',
                                 network = NULL,
                                 base.url = .defaultBaseUrl) {
    suid = getNetworkSuid(network)
    tbl <- paste0(namespace,table)
    res = cyrestGET(paste('networks',suid,'tables',tbl,'columns',sep = '/'),
                    base.url = base.url)
    col.names <- unlist(lapply(res, function(x) x$name))
    return(col.names)
}

# ------------------------------------------------------------------------------
#' @title Get Table Column Types 
#'
#' @description Retrieve the types of all columns in a table
#' @param table name of table, e.g., node, edge, network; default is "node"
#' @param namespace namespace of table, e.g., default
#' @param network (optional) Name or SUID of the network. Default is the "current" 
#' network active in Cytoscape.
#' @param base.url (optional) Ignore unless you need to specify a custom domain,
#' port or version to connect to the CyREST API. Default is http://localhost:1234
#' and the latest version of the CyREST API supported by this version of RCy3.
#' @return a named list of column types
#' @examples
#' \donttest{
#' getTableColumnTypes()
#' getTableColumnTypes('edge')
#' getTableColumnTypes('network')
#' }
#' @export
getTableColumnTypes <-  function(table = 'node',
                                 namespace = 'default',
                                 network = NULL,
                                 base.url = .defaultBaseUrl) {
    suid = getNetworkSuid(network)
    tbl <- paste0(namespace,table)
    res = cyrestGET(paste('networks',suid,'tables',tbl,'columns',sep = '/'),
                    base.url = base.url)
    col.names <- unlist(lapply(res, function(x) x$name))
    col.types <- unlist(lapply(res, function(x) x$type))
    col.types <- setNames(col.types,col.names)
    return(col.types)
}

# ------------------------------------------------------------------------------
#' @title Loads data into Cytoscape tables keyed by row
#'
#' @description This function loads data into Cytoscape node/edge/network tables provided a
#' common key, e.g., name. Data.frame column names will be used to set Cytoscape table column
#' names.
#' @details Numeric values will be stored as Doubles in Cytoscape tables. Integer values
#' will be stored as Integers. Character or mixed values will be stored as Strings. 
#' Logical values will be stored as Boolean. Existing columns with the same names 
#' will keep original type but values will be overwritten.
#' @param data (data.frame) each row is a node and columns contain node attributes
#' @param data.key.column (char) name of data.frame column to use as key; default is "row.names"
#' @param table (char) name of Cytoscape table to load data into, e.g., node, edge or network; default is "node"
#' @param table.key.column (char) name of Cytoscape table column to use as key; default is "name"
#' @param namespace namespace of table, e.g., default
#' @param network (optional) Name or SUID of the network. Default is the "current" 
#' network active in Cytoscape.
#' @param base.url (optional) Ignore unless you need to specify a custom domain,
#' port or version to connect to the CyREST API. Default is http://localhost:1234
#' and the latest version of the CyREST API supported by this version of RCy3.
#' @return server response
#' @importFrom BiocGenerics colnames
#' @export
loadTableData <- function(data,
                          data.key.column = 'row.names',
                          table = 'node',
                          table.key.column = 'name',
                          namespace = 'default',
                          network = NULL,
                          base.url = .defaultBaseUrl) {
    net.suid <- getNetworkSuid(network)
    table.key.column.values =  getTableColumns(table = table,
                                               columns = table.key.column,
                                               network = net.suid,
                                               base.url = base.url)
    
    ##ERROR if table.key.column.values is empty
    if (ncol(table.key.column.values) == 0)
        return("Failed to load data: Please check table.key.column")
    
    if (data.key.column == 'row.names')
        # if key in row.names...
        data$row.names <-
        row.names(data)  # then copy to new "row.names" column :)
    
    ##ERROR if data.key.column not in data
    if (!data.key.column %in% colnames(data))
        return("Failed to load data: Please check data.key.column")
    
    filter = data[, data.key.column] %in% table.key.column.values[, 1]
    
    ##ERROR if filter is empty
    if (!TRUE %in% filter)
        return("Failed to load data: Provided key columns do not contain any matches")
    
    data.subset = data[filter, ]
    
    #remove troublesome factors
    if (class(data.subset[, data.key.column]) == "factor")
        data.subset[, data.key.column] = levels(droplevels(data.subset[, data.key.column]))
    
    data.list <- c()
    for (i in 1:dim(data.subset)[1]) {
        #each rows
        rest <- list()
        for (j in 1:dim(data.subset)[2]) {
            #each column
            rest[[colnames(data.subset)[j]]] = data.subset[i, j]
        }
        data.list[[i]] <- rest
    }
    
    tbl = paste0(namespace, table) #add prefix
        
    # explicitly create columns for integer data, unless the column alread exists!
    existing.cols <- getTableColumnNames()
    data.types <- sapply(data.subset, typeof)
    for (i in 1:length(data.types)){
        if (data.types[i] == "integer" && !names(data.types[i]) %in% existing.cols){
            cyrestPOST(paste('networks',net.suid,'tables',tbl,'columns',sep='/'),
                       body=list(name=names(data.types[i]),
                                 type="Integer"),
                       base.url = base.url)
        }
    }
    
    cyrestPUT(paste('networks', net.suid, "tables", tbl, sep = '/'),
              body = list(key = table.key.column,
                          dataKey = data.key.column,
                          data = data.list),
              base.url = base.url)
    return(sprintf("Success: Data loaded in %s table", tbl))
}

# ------------------------------------------------------------------------------
#' @title Map Table Column
#'
#' @description Perform identifier mapping using an existing column of supported
#' identifiers to populate a new column with identifiers mapped to the originals.
#' @param column Name of column containing identifiers of type specified by 
#' \code{map.from}.
#' @param species Common name for species associated with identifiers, e.g., Human. 
#' See details.
#' @param map.from Type of identifier found in specified \code{column}. See details.
#' @param map.to Type of identifier to populate in new column. See details.
#' @param force.single (optional) Whether to return only first result in cases
#' of one-to-many mappings; otherwise the new column will hold lists of identifiers.
#' Default is TRUE.
#' @param table (optional) Name of table, e.g., node (default), edge or network
#' @param namespace (optional) Namespace of table, e.g., default (default), shared
#' or hidden
#' @param network (optional) Name or SUID of the network. Default is the "current" 
#' network active in Cytoscape.
#' @param base.url (optional) Ignore unless you need to specify a custom domain,
#' port or version to connect to the CyREST API. Default is http://localhost:1234
#' and the latest version of the CyREST API supported by this version of RCy3.
#' @details Supported species: Human, Mouse, Rat, Frog, Zebrafish, Fruit fly,
#' Mosquito, Worm, Arabidopsis thaliana, Yeast, E. coli, Tuberculosis.
#' 
#' Supported identifier types (depending on species): Ensembl, Entrez Gene, 
#' Uniprot-TrEMBL, miRBase, UniGene,  HGNC (symbols), MGI, RGD, SGD, ZFIN, 
#' FlyBase, WormBase, TAIR.
#' @return dataframe with map.from and map.to columns. Beware: if map.to is not unique,
#' it will be suffixed with an incrementing number in parentheses, e.g., if 
#' mapIdentifiers is repeated on the same network. However, the original map.to 
#' column will be returned regardless.
#' @examples \donttest{
#' mapped.cols <- mapTableColumn('name','Yeast','Ensembl','SGD')
#' #          name        SGD
#' #17920  YER145C S000000947
#' #17921  YMR058W S000004662
#' #17922  YJL190C S000003726
#' #...
#' }
#' @export
mapTableColumn <- function(column, species, map.from, map.to, force.single=TRUE,
                           table='node', namespace='default',
                           network=NULL, base.url=.defaultBaseUrl){
    net.suid <- getNetworkSuid(network)
    tbl <- paste(net.suid,namespace,table, sep=" ")
    
    if(force.single)
        fs <- "true"
    else
        fs <- "false"
    
    all.cols <- getTableColumnNames(table, namespace, network, base.url)
    if(!column %in% all.cols)
        stop(sprintf("ERROR:mapIdentifiers, %s does not exist", column))
    
    commandsPOST(paste0('idmapper map column columnName="',column,
                        '" forceSingle="',fs,
                        '" mapFrom="',map.from,
                        '" mapTo="',map.to,
                        '" species="',species,
                        '" table="',tbl,'"'))
    
    getTableColumns(table=table, columns=c(column,map.to), namespace = namespace, 
                    network = network, base.url = base.url)
}

# ------------------------------------------------------------------------------
#' @title Rename Table Column
#'
#' @description Sets a new name for a column.
#' @param column Name of the column to rename
#' @param new.name New name for the specified column
#' @param table (optional) Name of table, e.g., node (default), edge or network
#' @param namespace (optional) Namespace of table, e.g., default (default), shared
#' or hidden
#' @param network (optional) Name or SUID of the network. Default is the "current" 
#' network active in Cytoscape.
#' @param base.url (optional) Ignore unless you need to specify a custom domain,
#' port or version to connect to the CyREST API. Default is http://localhost:1234
#' and the latest version of the CyREST API supported by this version of RCy3.
#' @return None
#' @examples \donttest{
#' renameTableColumn('exp','log2FC')
#' }
#' @export
renameTableColumn <- function(column, new.name, 
                              table='node', namespace='default', 
                              network=NULL, base.url=.defaultBaseUrl){
    net.suid <- getNetworkSuid(network)
    tbl <- paste0(namespace,table)
    
    cyrestPUT(paste('networks',net.suid,'tables',tbl,'columns',sep="/"),
              body = list(oldName=column,newName=new.name),
              base.url = base.url)
    
}