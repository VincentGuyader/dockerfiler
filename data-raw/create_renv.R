#' Title
#'
#' @param path
#' @param dev_pkg
#' @param folder_to_include
#' @param output
#'
#' @return
#' @export
#' @importFrom attachment att_from_rscripts att_from_rmds install_if_missing
#' @importFrom renv snapshot
#' @importFrom cli cli_bullets
#' @examples
create_renv_for_dev <- function(path=".",
  dev_pkg = c("renv","devtools", "roxygen2", "usethis", "pkgload",
  "testthat", "covr", "attachment","pak","dockerfiler",
  "remotes::install_github('ThinkR-open/checkhelper')"),
  folder_to_include = c("dev/","data-raw/"),
  output = "renv.lock"
  ){

  from_r_script <-   file.path(path,folder_to_include) %>%
    map(attachment::att_from_rscripts) %>%
    unlist()


  from_rmd <-   file.path(path,folder_to_include) %>%
    map(attachment::att_from_rmds)%>%
    unlist()


  pkg_list <- c(
    attachment::att_from_description(),
    from_r_script,from_rmd,
    dev_pkg
  )
  pkg_list

  attachment::install_if_missing(pkg_list)
  cli::cli_bullets(glue::glue("create renv.lock at {output}"))
  renv::snapshot(packages = pkg_list,lockfile = output,prompt = FALSE)

 output

}


#' @rdname create_renv_for_dev
create_renv_for_prod <-function(path=".",output = "renv.lock.prod"){
  create_renv_for_dev(path = path,dev_pkg = NULL,folder_to_include=NULL,output = output)
}

#
# lock_file_prod <-create_renv_for_prod()
# create_renv_for_dev()
#
# socle <- dock_from_renv(lockfile = lock_file_prod,
#                                      distro = "focal",
#                                      FROM = "rocker/verse",repos = "https://cran.rstudio.com"
# )



#' Title
#'
#' @param lockfile
#' @param output_dir
#'
#' @export
#'
add_dockerfile_with_renv_ <- function(
  path = ".",
  lockfile = NULL,
  output_dir = fs::path(tempdir(), "deploy"),
  distro = "focal",
  FROM = "rocker/verse",
  AS = NULL,
  sysreqs = TRUE,
  repos = c(CRAN = "https://cran.rstudio.com/"),
  expand = FALSE,
  extra_sysreqs = NULL,

  update_tar_gz = TRUE
  # build_golem_from_source = TRUE,

  ){

  dir.create(output_dir)
   if ( is.null(lockfile)){
     lockfile <-create_renv_for_prod(path = path,output = file.path(output_dir,"renv.lock.prod"))
  }

  file.copy(from = lockfile,to = output_dir)
  socle <- dockerfiler::dock_from_renv(lockfile = lockfile,
                          distro = distro,
                          FROM = FROM,repos = repos,
                          AS = AS,
                          sysreqs = sysreqs,expand = expand,
                          extra_sysreqs = extra_sysreqs
  )
  socle$write(as = file.path(output_dir, "Dockerfile_socle"))



  my_dock <- Dockerfile$new(FROM = paste0(golem::get_golem_name(),"_socle"))
  my_dock$RUN(r(renv::restore()))

  # if (!build_from_source) {
    if (update_tar_gz) {
      old_version <- list.files(path = output_dir,pattern = 'paste0(golem::get_golem_name(), "_*.tar.gz")',full.names = TRUE)
      # file.remove(old_version)
      if (length(old_version) > 0) {
        lapply(old_version, file.remove)
        lapply(old_version, unlink, force = TRUE)
        cat_red_bullet(
          sprintf(
            "%s were removed from folder",
            paste(
              old_version,
              collapse = ", "
            )
          )
        )
      }


      if (
        isTRUE(
          requireNamespace(
            "pkgbuild",
            quietly = TRUE
          )
        )
      ) {
        out <- pkgbuild::build(
          path = ".",
          dest_path = output_dir,
          vignettes = FALSE
        )
        if (missing(out)) {
          cat_red_bullet("Error during tar.gz building")
        } else {
          use_build_ignore(files = out)
          cat_green_tick(
            sprintf(
              " %s created.",
              out
            )
          )
        }
      } else {
        stop("please install {pkgbuild}")
      }
    }
    # we use an already built tar.gz file

    my_dock$COPY(
      from =
        file.path(output_dir,
        paste0(golem::get_golem_name(), "_*.tar.gz")
        ),
      to = "/app.tar.gz")
    my_dock$RUN("R -e 'remotes::install_local(\"/app.tar.gz\",upgrade=\"never\")'")
    my_dock$RUN("rm /app.tar.gz")
    my_dock
  }





add_dockerfile_with_renv_shinyproxy <-function( path = ".",
                                                lockfile = NULL,
                                                output_dir = fs::path(tempdir(), "deploy"),
                                                distro = "focal",
                                                FROM = "rocker/verse",
                                                AS = NULL,
                                                sysreqs = TRUE,
                                                repos = c(CRAN = "https://cran.rstudio.com/"),
                                                expand = FALSE,
                                                extra_sysreqs = NULL,

                                                update_tar_gz = TRUE){
 base_dock <-  add_dockerfile_with_renv_(
    path = path,
    lockfile = lockfile,
    output_dir = output_dir,
    distro = distro,
    FROM = FROM,
    AS = AS,
    sysreqs = sysreqs,
    repos = repos,
    expand = expand,
    extra_sysreqs = extra_sysreqs,
    update_tar_gz = update_tar_gz
  )



 # pour shinyproxy
 base_dock$EXPOSE(3838)
 base_dock$CMD(sprintf(" [\"R\", \"-e\", \"options('shiny.port'=3838,shiny.host='0.0.0.0');%s::run_app()\"]",
                     golem::get_golem_name()))
 base_dock
 base_dock$write(as = file.path(output_dir, "Dockerfile"))

 out <- glue::glue("docker build -f Dockerfile_socle -t {paste0(golem::get_golem_name(),'_socle')} .
           docker build -f Dockerfile -t {paste0(golem::get_golem_name(),':latest')} .
           # pour tester en local sur 127.0.0.1:3838
           docker run -v -p 3838:3838 {paste0(golem::get_golem_name(),':latest')}
          ")
 cat(out,file = file.path(output_dir, "README"))
}
