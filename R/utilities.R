
#' @importFrom xml2 read_xml
readVocab <- function(url) {
  res <- try(read_xml(url), silent = TRUE)

  if (inherits(res, "try-error")) {

    warning(attr(res, "condition")$message)
    return ("")
  }

  res
}


#' @importFrom xml2 read_xml
#' @importFrom xml2 as_list
parseVocab <- function(xml) {

  if (identical(xml,"")) {
    return(data.frame())
  }

  # convert to list
  data <- as_list(xml)

  # process into a data.frame
  out <- toVocabdf(data[[1]][[1]])

  # exit if no data is being returned
  if (nrow(out) == 0) {
    return(NULL)
  }

  out
}


#' @importFrom xml2 as_list
parseVocabDetail <- function(xml) {

  if (identical(xml, "")) {
    return(data.frame())
  }

  # convert to list
  data <- as_list(xml)
  CodeDetail <- data$GetCodeDetailResponse$CodeDetail

  # process into a data.frame
  header <- toVocabdf(list(CodeDetail[c("Key", "Description", "LongDescription", "Modified", "Deprecated")]))

  # get parents
  parents <- CodeDetail$ParentRelation
  parent_code <- toVocabdf(lapply(parents, "[[", "Code"))
  parent_code_type <- toVocabdf(lapply(parents, "[[", "CodeType"))

  # get children
  children <- CodeDetail$ChildRelation
  child_code <- toVocabdf(lapply(children, "[[", "Code"))
  child_code_type <- toVocabdf(lapply(children, "[[", "CodeType"))

  # restructure
  out <- list(detail = header,
              parents = list(code_types = parent_code_type, codes = parent_code),
              children = list(code_types = child_code_type, codes = child_code))

  # return
  out
}

#' @importFrom utils type.convert
toVocabdf <- function(x) {
  # convert to data.frame
  out <-
    lapply(
      x,
      function(Code) {
        as.data.frame(
          lapply(
            Code,
            function(x) if (length(x) == 0) NA else x[[1]]
          ),
          stringsAsFactors = FALSE
        )
      }
    )
  out <- do.call(rbind, out)
  row.names(out) <- NULL

  # convert non text columns
  out$Key <- type.convert(out$Key, as.is = TRUE)
  out$Modified <- as.Date(out$Modified)
  if ("Deprecated" %in% names(out)) {
    out$Deprecated <- out$Deprecated == "true"
  }

  # clean trailing white space from text columns
  charcol <- which(sapply(out, is.character))
  out[charcol] <- lapply(out[charcol], trimws)

  out
}



checkVocabWebserviceOK <- function() {
  # return TRUE if webservice server is good, FALSE otherwise
  out <- readVocab(url = "https://vocab.ices.dk/services/pox/GetCodeDetail/SpecWoRMS/101170")

  # Check the server is not down by insepcting the XML response for internal server error message.
  if (grepl("Internal Server Error", out)) {
    warning("Web service failure: the server seems to be down, please try again later.")
    FALSE
  } else {
    TRUE
  }
}

# returns TRUE if correct operating system is passed as an argument
os.type <- function (type = c("unix", "windows", "other"))
{
  type <- match.arg(type)
  if (type %in% c("windows", "unix")) {
    .Platform$OS.type == type
  } else {
    TRUE
  }
}
