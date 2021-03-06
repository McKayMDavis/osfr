#' Create a new folder on OSF project.
#'
#' @param id Parent OSF project id (osf.io/XXXX; just XXXX) to create folder in
#' @param path Name of the folder (cannot handle recursive at the moment).
#' @param return Which waterbutler URLs should be returned. Defaults to root to mimick old functions behavior.
#' @description Creates a root folder or a root folder and the nested subfolders.  Will also create subfolders in a previously created root folder.
#' @return Waterbutler URL for folder "root", last subfolder "sub", or all folders created "all" depanding on the selection input for `return`
#' @export

create_folder <- function(id, path, return = c("sub", "root", "all")[2]) {

  config <- get_config(TRUE)

  typ <- process_type(id, private = TRUE)
  if (typ != "nodes") {
    stop("Cannot create new folder if no node ID is specified.")
  }

  lvls <- strsplit(path, "\\/")[[1]]
  path_root <- lvls[1]
  path_sub <- NULL
  if (length(lvls) > 1) path_sub <- strsplit(path, "\\/")[[1]][2:length(lvls)]

  # Create root folder
  url_osf <- construct_link_files(id,
                                  request = paste0("?kind=folder&name=", path_root))
  url_osf <- rm_space(url_osf)
  call <- httr::PUT(url_osf, config = config)

  if (call$status_code == 409) {
    warning("Conflict in folder naming. Root folder with this name already exists.")
  } else if (call$status_code != 201) {
    stop("Unsuccessful folder creation.")
  }

## Addition to create subfolders if root folder was already created

  if (call$status_code == 201) {
    res <- process_json(call)
    res_root_link <- res$data$links$new_folder
  } else if (call$status_code == 409) {
    message("Attempting to create subfolders under previously created root folder")
    fi <- get_files_info(id, private = TRUE)
    fi_row <- which(fi$materialized == paste0(pre_slash(path_root), "/"))
    res_root_link <- paste0(fi[fi_row, "href"],'?kind=folder')
  }

### end root folder addition check.




  # Create subfolders and keep the url json information for each creation.

  res_sub <- vector("list", length(path_sub))
  res_data_link <- res_root_link

  for (i in seq_along(path_sub)){

    url_osf_sub <- paste0(res_data_link, "&name=", path_sub[i])
    call_sub <- httr::PUT(url_osf_sub, config = config)

    if (call_sub$status_code == 409) {
      stop("Conflict in sub folder naming. A subfolder with this name already exists.")
    } else if (call_sub$status_code != 201) {
      stop("Unsuccessful subfolder creation.")
    }

    res_sub[[i]] <- process_json(call_sub)
    res_data_link <- res_sub[[i]]$data$links$new_folder

  }
  names(res_sub) = path_sub

  # This if else patch depends on the return statement.  Wasn't sure which to default.  So added a return value in
  # function that can prescribe which is returned.

  if(return == "all") {
    res_sub_links <- lapply(res_sub, function(x) x$data$links$new_folder)

    out <- c(res$data$links$new_folder, res_sub_links)
    names(out)[1] <- path_root
  } else if (return == "root") {
    out <- res_root_link
  } else if (return == "sub") {
    out <- res_sub[[length(res_sub)]]$data$links$new_folder
  } else {
    out <- NULL
  }

  invisible(out)

}

#' Delete a folder on the OSF
#'
#' @param url Waterbutler link
#'
#' @return Boolean, deletion success?
#' @seealso \code{\link{create_folder}}
#' @export

delete_folder <- function(url) {
  config <- get_config(TRUE)

  call <- httr::DELETE(url, config = config)

  if (call$status_code != 204) {
    stop('Failed to delete folder. Be sure to specify Waterbutler link.')
  }

  return(TRUE)
}
